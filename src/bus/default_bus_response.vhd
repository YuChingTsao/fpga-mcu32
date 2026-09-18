library ieee;
use ieee.std_logic_1164.all;

library work;
use work.mcu32_bus_pkg.all;

entity Default_Bus_Response is
    port (
        ----------------------------------------------------------------
        -- High whenever the CPU requests a read or write
        ----------------------------------------------------------------
        access_i : in std_logic;

        ----------------------------------------------------------------
        -- Address status from Address_Decoder
        ----------------------------------------------------------------
        aligned_i : in std_logic;
        decoded_i : in std_logic;

        ----------------------------------------------------------------
        -- Safe data returned for an invalid read
        ----------------------------------------------------------------
        default_rdata_o :
            out std_logic_vector(DATA_WIDTH_C - 1 downto 0);

        ----------------------------------------------------------------
        -- High for an active invalid or misaligned access
        ----------------------------------------------------------------
        bus_error_o : out std_logic
    );
end entity Default_Bus_Response;

architecture rtl of Default_Bus_Response is
begin

    ----------------------------------------------------------------
    -- Invalid reads return a recognizable debug value.
    ----------------------------------------------------------------
    default_rdata_o <= DEFAULT_READ_DATA_C;

    ----------------------------------------------------------------
    -- Generate the bus-error indication.
    ----------------------------------------------------------------
    process(access_i, aligned_i, decoded_i)
    begin

        if
            access_i = '1' and
            (
                aligned_i = '0' or
                decoded_i = '0'
            )
        then
            bus_error_o <= '1';
        else
            bus_error_o <= '0';
        end if;

    end process;

end architecture rtl;