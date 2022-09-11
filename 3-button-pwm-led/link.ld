ENTRY(_start)

MEMORY
{
    ram : ORIGIN = 0x8000, LENGTH = 0x1000
}

SECTIONS
{
    .text : {
        _stext = .;
        *(.init*)
        . = ALIGN(4);
        _etext = .;
    } > ram
    .data : {
        _sdata = .;
        *(.data*)
        . = ALIGN(4);
        _edata = .;
    } > ram
    .bss : {
        _sbss = .;
        *(.bss*)
        . = ALIGN(4);
        _ebss = .;
    } > ram
}
