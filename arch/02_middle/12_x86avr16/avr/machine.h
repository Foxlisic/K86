
// Чтение и запись в память и порты на физическом уровне
byte machine_read (dword address) {
    return 0x00;
}

void machine_write (dword address, byte data) {
}

byte io_read (word port) {
    return 0xff;
}

void io_write(word port, byte data) {
}
