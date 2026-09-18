library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Data_RAM_32 is
    generic (
        -- 2^10 = 1024 words by default.
        ADDR_WIDTH : positive := 10
    );
    port (
        clk_i : in std_logic;
        rst_i : in std_logic;

        ----------------------------------------------------------------
        -- Bus control
        ----------------------------------------------------------------
        cs_i : in std_logic;  -- Chip select from address decoder
        rd_i : in std_logic;  -- Read request
        wr_i : in std_logic;  -- Write request

        ----------------------------------------------------------------
        -- 32-bit byte address from CPU or memory-mapped bus
        ----------------------------------------------------------------
        addr_i : in std_logic_vector(31 downto 0);

        ----------------------------------------------------------------
        -- Write interface
        ----------------------------------------------------------------
        wdata_i   : in std_logic_vector(31 downto 0);
        byte_en_i : in std_logic_vector(3 downto 0);

        ----------------------------------------------------------------
        -- Read interface
        ----------------------------------------------------------------
        rdata_o : out std_logic_vector(31 downto 0);

        ----------------------------------------------------------------
        -- Status outputs
        ----------------------------------------------------------------
        read_valid_o  : out std_logic;
        write_valid_o : out std_logic;
        addr_error_o  : out std_logic
    );
end entity Data_RAM_32;

architecture rtl of Data_RAM_32 is

    constant RAM_DEPTH : natural := 2 ** ADDR_WIDTH;

    ----------------------------------------------------------------
    -- For ADDR_WIDTH = 10:
    --
    -- RAM_DEPTH = 1024 words
    -- Total size = 1024 × 4 bytes = 4096 bytes
    -- Word index = addr_i(11 downto 2)
    ----------------------------------------------------------------
    type ram_type is array (
        0 to RAM_DEPTH - 1
    ) of std_logic_vector(31 downto 0);

    signal ram : ram_type :=
        (others => (others => '0'));

    signal rdata_reg : std_logic_vector(31 downto 0) :=
        (others => '0');

    signal read_valid_reg  : std_logic := '0';
    signal write_valid_reg : std_logic := '0';

    signal word_index :
        natural range 0 to RAM_DEPTH - 1 := 0;

    signal request_int      : std_logic;
    signal misaligned_int   : std_logic;
    signal range_error_int  : std_logic;
    signal bad_op_int       : std_logic;
    signal error_int        : std_logic;

    constant UPPER_ADDR_ZERO :
        std_logic_vector(31 downto ADDR_WIDTH + 2) :=
        (others => '0');

    ----------------------------------------------------------------
    -- Quartus memory-inference hint
    ----------------------------------------------------------------
    attribute ramstyle : string;
    attribute ramstyle of ram : signal is "M9K";

begin

    ----------------------------------------------------------------
    -- Safety check for the 32-bit byte-addressed RAM
    ----------------------------------------------------------------
    assert ADDR_WIDTH <= 29
        report
            "Data_RAM_32: ADDR_WIDTH must be <= 29 for 32-bit byte addressing."
        severity failure;

    ----------------------------------------------------------------
    -- Convert the byte address to a word index.
    --
    -- Address bits 1 downto 0 are not part of the word index because
    -- each 32-bit word occupies four bytes.
    ----------------------------------------------------------------
    word_index <=
        to_integer(
            unsigned(addr_i(ADDR_WIDTH + 1 downto 2))
        );

    ----------------------------------------------------------------
    -- A request exists when the RAM is selected and either a read or
    -- write operation is requested.
    ----------------------------------------------------------------
    request_int <= cs_i and (rd_i or wr_i);

    ----------------------------------------------------------------
    -- Word-aligned access only.
    --
    -- Valid addresses must have addr_i(1 downto 0) = "00".
    ----------------------------------------------------------------
    misaligned_int <=
        '1' when addr_i(1 downto 0) /= "00"
        else '0';

    ----------------------------------------------------------------
    -- Range checking
    --
    -- For 1024 words, valid byte addresses are:
    --
    -- 0x0000_0000 through 0x0000_0FFF
    ----------------------------------------------------------------
    range_error_int <=
        '1'
        when addr_i(31 downto ADDR_WIDTH + 2) /=
             UPPER_ADDR_ZERO
        else
        '0';

    ----------------------------------------------------------------
    -- Simultaneous read and write is illegal for this simple RAM.
    ----------------------------------------------------------------
    bad_op_int <= rd_i and wr_i;

    ----------------------------------------------------------------
    -- Combined error output
    ----------------------------------------------------------------
    error_int <=
        request_int and (
            misaligned_int or
            range_error_int or
            bad_op_int
        );

    addr_error_o <= error_int;

    ----------------------------------------------------------------
    -- Synchronous RAM process
    ----------------------------------------------------------------
    process(clk_i)
    begin
        if rising_edge(clk_i) then

            if rst_i = '1' then

                ----------------------------------------------------
                -- Do not clear the RAM contents during reset.
                -- Only clear output and status registers.
                ----------------------------------------------------
                rdata_reg       <= (others => '0');
                read_valid_reg  <= '0';
                write_valid_reg <= '0';

            else

                ----------------------------------------------------
                -- Valid outputs are normally one-clock pulses.
                ----------------------------------------------------
                read_valid_reg  <= '0';
                write_valid_reg <= '0';

                if request_int = '1' and error_int = '0' then

                    if wr_i = '1' then

                        --------------------------------------------
                        -- Byte-enable write
                        --
                        -- For a normal 32-bit store, use:
                        -- byte_en_i = "1111"
                        --------------------------------------------
                        for i in 0 to 3 loop

                            if byte_en_i(i) = '1' then

                                ram(word_index)(
                                    (8 * i) + 7 downto (8 * i)
                                ) <= wdata_i(
                                    (8 * i) + 7 downto (8 * i)
                                );

                            end if;

                        end loop;

                        write_valid_reg <= '1';

                    elsif rd_i = '1' then

                        --------------------------------------------
                        -- Registered synchronous read
                        --------------------------------------------
                        rdata_reg      <= ram(word_index);
                        read_valid_reg <= '1';

                    end if;

                end if;

            end if;

        end if;
    end process;

    ----------------------------------------------------------------
    -- Outputs
    ----------------------------------------------------------------
    rdata_o       <= rdata_reg;
    read_valid_o  <= read_valid_reg;
    write_valid_o <= write_valid_reg;

end architecture rtl;