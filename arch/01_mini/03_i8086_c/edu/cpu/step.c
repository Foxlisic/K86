// Исполнение инструкции
void STEP() {
    
    // Прочитать опкод
    opcode = FETCH_OPCODE();

    // Прочитать ModRM
    if (instruction_has_modrm[ opcode ]) {
        modrm_ea = FETCH_MODRM(i_seg_over, i_seg_val);
    }
    
    // Выполнить инструкцию
    instruction[ opcode ]();
}
