__flash = 0x80000080;
__flash_size = 128K-0x80;
__ram = 0x80020000;
__ram_size = 128K;
__stack_size = 8K;

INCLUDE picolibc.ld

# TODO: Properly inject vector table at the actual flash offset
