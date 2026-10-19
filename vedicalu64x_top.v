`timescale 1ns/1ps
// =====================================================================
// vedicalu64x_top.v
// VedicALU-64X - 64-bit 5-stage pipelined RISC processor
//
// Pipeline:
// IF -> IF/ID -> ID -> ID/EX -> EX -> EX/MEM -> MEM -> MEM/WB -> WB
//
// Power optimization:
// DEBUG_ENABLE controls the external debug outputs.
//
// DEBUG_ENABLE = 1:
//     Normal simulation/debug operation.
//
// DEBUG_ENABLE = 0:
//     debug_pc, debug_result and debug_halted are forced to zero.
//     This prevents unnecessary switching on the external debug outputs
//     during power analysis.
//
// IMPORTANT:
//     The processor datapath itself remains functional.
//     The Vedic multiplier optimization is implemented separately
//     inside alu_64bit.v.
// =====================================================================

`include "isa_defines.vh"


module vedicalu64x_top #(
    parameter DEBUG_ENABLE = 1'b1
) (
    input  wire        clk,
    input  wire        rst,

    // ---------------------------------------------------------------
    // Debug outputs
    // ---------------------------------------------------------------
    output wire [31:0] debug_pc,
    output wire [63:0] debug_result,
    output wire        debug_halted
);


    // =================================================================
    // INTERNAL PROCESSOR SIGNALS
    // =================================================================

    wire [31:0] pc;
    wire        pc_stall;

    wire        branch_taken;
    wire [31:0] branch_target;

    wire [31:0] if_instr;


    // =================================================================
    // POWER-OPTIMIZED DEBUG OUTPUTS
    // =================================================================
    //
    // When DEBUG_ENABLE = 1:
    //     Outputs behave exactly like the original design.
    //
    // When DEBUG_ENABLE = 0:
    //     Outputs remain at zero.
    //
    // This is particularly useful for Vivado power analysis because
    // debug_pc and debug_result were previously responsible for almost
    // all of the estimated I/O power.
    // =================================================================

    assign debug_pc =
        DEBUG_ENABLE ? pc : 32'b0;

    assign debug_result =
        DEBUG_ENABLE ? wb_data : 64'b0;

    assign debug_halted =
        DEBUG_ENABLE ? halted : 1'b0;


    // =================================================================
    // IF - INSTRUCTION FETCH
    // =================================================================

    program_counter u_pc (
        .clk           (clk),
        .rst           (rst),
        .stall         (pc_stall),
        .branch_taken  (branch_taken),
        .branch_target (branch_target),
        .pc            (pc)
    );


    // -----------------------------------------------------------------
    // Instruction Memory
    // -----------------------------------------------------------------

    instruction_memory u_imem (
        .pc   (pc),
        .instr(if_instr)
    );


    // =================================================================
    // IF / ID PIPELINE REGISTER
    // =================================================================

    wire        if_id_stall;
    wire [31:0] id_pc;
    wire [31:0] id_instr;

    if_id_reg u_if_id (
        .clk      (clk),
        .rst      (rst),
        .stall    (if_id_stall),
        .flush    (branch_taken),

        .pc_in    (pc),
        .instr_in (if_instr),

        .pc_out   (id_pc),
        .instr_out(id_instr)
    );


    // =================================================================
    // ID - INSTRUCTION DECODE
    // =================================================================

    wire [5:0] id_opcode;
    wire [4:0] id_rs1_addr;
    wire [4:0] id_rs2_field;
    wire [4:0] id_rd_rtype;
    wire [5:0] id_funct;

    assign id_opcode    = id_instr[31:26];
    assign id_rs1_addr  = id_instr[25:21];
    assign id_rs2_field = id_instr[20:16];
    assign id_rd_rtype  = id_instr[15:11];
    assign id_funct     = id_instr[10:5];


    // =================================================================
    // CONTROL UNIT
    // =================================================================

    wire       id_reg_write;
    wire       id_alu_src;
    wire       id_mem_read;
    wire       id_mem_write;
    wire       id_mem_to_reg;

    wire       id_branch_beq;
    wire       id_branch_bne;
    wire       id_jump;
    wire       id_halt;
    wire       id_is_rtype;

    wire [3:0] id_ctrl_alu_op;
    wire [3:0] id_alu_op;


    control_unit u_control (
        .opcode      (id_opcode),

        .reg_write   (id_reg_write),
        .alu_src     (id_alu_src),

        .mem_read    (id_mem_read),
        .mem_write   (id_mem_write),
        .mem_to_reg  (id_mem_to_reg),

        .branch_beq  (id_branch_beq),
        .branch_bne  (id_branch_bne),

        .jump        (id_jump),
        .halt        (id_halt),

        .is_rtype    (id_is_rtype),
        .alu_op      (id_ctrl_alu_op)
    );


    // =================================================================
    // ALU CONTROL
    // =================================================================

    alu_control u_alu_control (
        .is_rtype   (id_is_rtype),
        .funct      (id_funct),

        .alu_op_in  (id_ctrl_alu_op),
        .alu_op_out (id_alu_op)
    );


    // =================================================================
    // REGISTER FILE
    // =================================================================

    wire [4:0] id_rd_addr_w;

    assign id_rd_addr_w =
        id_is_rtype ? id_rd_rtype : id_rs2_field;


    wire [63:0] id_rs1_data;
    wire [63:0] id_rs2_data;
    wire [63:0] id_rd_acc_data;

    wire [63:0] wb_data;

    wire        wb_reg_write;
    wire [4:0]  wb_rd_addr;


    register_file u_regfile (
        .clk        (clk),
        .we         (wb_reg_write),

        .rs1_addr   (id_rs1_addr),
        .rs2_addr   (id_rs2_field),

        .rd_addr_r  (id_rd_rtype),

        .rd_addr_w  (wb_rd_addr),
        .wdata      (wb_data),

        .rs1_data   (id_rs1_data),
        .rs2_data   (id_rs2_data),
        .rd_data_r  (id_rd_acc_data)
    );


    // =================================================================
    // IMMEDIATE GENERATOR
    // =================================================================

    wire [63:0] id_imm_ext;

    imm_gen u_imm_gen (
        .instr   (id_instr),
        .imm_ext (id_imm_ext)
    );


    // =================================================================
    // HAZARD DETECTION
    // =================================================================

    wire        ex_mem_read_cur;
    wire [4:0]  ex_rd_addr_cur;

    wire        load_use_stall;


    hazard_unit u_hazard (
        .ex_mem_read (ex_mem_read_cur),
        .ex_rd_addr  (ex_rd_addr_cur),

        .id_rs1_addr (id_rs1_addr),
        .id_rs2_addr (id_rs2_field),

        .stall       (load_use_stall)
    );


    // -----------------------------------------------------------------
    // Stall control
    // -----------------------------------------------------------------

    assign if_id_stall = load_use_stall;

    // When HALT is reached, freeze the PC.
    assign pc_stall =
        load_use_stall || halted;


    // =================================================================
    // ID / EX PIPELINE REGISTER
    // =================================================================

    wire [31:0] ex_pc;

    wire [63:0] ex_rs1_data;
    wire [63:0] ex_rs2_data;
    wire [63:0] ex_rd_acc_data;
    wire [63:0] ex_imm_ext;

    wire [4:0] ex_rs1_addr;
    wire [4:0] ex_rs2_addr;
    wire [4:0] ex_rd_addr;

    wire [3:0] ex_alu_op;

    wire       ex_reg_write;
    wire       ex_alu_src;
    wire       ex_mem_write;

    wire       ex_mem_to_reg;
    wire       ex_branch_beq;
    wire       ex_branch_bne;
    wire       ex_jump;
    wire       ex_halt;


    assign ex_rd_addr_cur = ex_rd_addr;


    id_ex_reg u_id_ex (
        .clk            (clk),
        .rst            (rst),

        .bubble         (load_use_stall || branch_taken),

        .pc_in          (id_pc),

        .rs1_data_in    (id_rs1_data),
        .rs2_data_in    (id_rs2_data),
        .rd_acc_data_in (id_rd_acc_data),

        .imm_ext_in     (id_imm_ext),

        .rs1_addr_in    (id_rs1_addr),
        .rs2_addr_in    (id_rs2_field),
        .rd_addr_in     (id_rd_addr_w),

        .alu_op_in      (id_alu_op),

        .reg_write_in   (id_reg_write),
        .alu_src_in     (id_alu_src),

        .mem_read_in    (id_mem_read),
        .mem_write_in   (id_mem_write),
        .mem_to_reg_in  (id_mem_to_reg),

        .branch_beq_in  (id_branch_beq),
        .branch_bne_in  (id_branch_bne),

        .jump_in        (id_jump),
        .halt_in        (id_halt),

        .pc_out         (ex_pc),

        .rs1_data_out   (ex_rs1_data),
        .rs2_data_out   (ex_rs2_data),
        .rd_acc_data_out(ex_rd_acc_data),

        .imm_ext_out    (ex_imm_ext),

        .rs1_addr_out   (ex_rs1_addr),
        .rs2_addr_out   (ex_rs2_addr),
        .rd_addr_out    (ex_rd_addr),

        .alu_op_out     (ex_alu_op),

        .reg_write_out  (ex_reg_write),
        .alu_src_out    (ex_alu_src),

        .mem_read_out   (ex_mem_read_cur),
        .mem_write_out  (ex_mem_write),
        .mem_to_reg_out (ex_mem_to_reg),

        .branch_beq_out (ex_branch_beq),
        .branch_bne_out (ex_branch_bne),

        .jump_out       (ex_jump),
        .halt_out       (ex_halt)
    );


    // =================================================================
    // EX - FORWARDING
    // =================================================================

    wire [1:0] fwd_rs1_sel;
    wire [1:0] fwd_rs2_sel;
    wire [1:0] fwd_acc_sel;

    wire       ex_mem_reg_write_cur;
    wire       mem_wb_reg_write_cur;

    wire [4:0] ex_mem_rd_addr_cur;
    wire [4:0] mem_wb_rd_addr_cur;

    wire [63:0] ex_mem_alu_result_cur;


    forwarding_unit u_forward (
        .id_ex_rs1_addr    (ex_rs1_addr),
        .id_ex_rs2_addr    (ex_rs2_addr),
        .id_ex_rd_addr     (ex_rd_addr),

        .ex_mem_reg_write  (ex_mem_reg_write_cur),
        .ex_mem_rd_addr    (ex_mem_rd_addr_cur),

        .mem_wb_reg_write  (mem_wb_reg_write_cur),
        .mem_wb_rd_addr    (mem_wb_rd_addr_cur),

        .fwd_rs1_sel       (fwd_rs1_sel),
        .fwd_rs2_sel       (fwd_rs2_sel),
        .fwd_acc_sel       (fwd_acc_sel)
    );


    // =================================================================
    // FORWARDING MUXES
    // =================================================================

    wire [63:0] ex_rs1_fwd;
    wire [63:0] ex_rs2_fwd;
    wire [63:0] ex_acc_fwd;


    assign ex_rs1_fwd =
        (fwd_rs1_sel == 2'b01) ? ex_mem_alu_result_cur :
        (fwd_rs1_sel == 2'b10) ? wb_data :
                                  ex_rs1_data;


    assign ex_rs2_fwd =
        (fwd_rs2_sel == 2'b01) ? ex_mem_alu_result_cur :
        (fwd_rs2_sel == 2'b10) ? wb_data :
                                  ex_rs2_data;


    assign ex_acc_fwd =
        (fwd_acc_sel == 2'b01) ? ex_mem_alu_result_cur :
        (fwd_acc_sel == 2'b10) ? wb_data :
                                  ex_rd_acc_data;


    // =================================================================
    // ALU B OPERAND
    // =================================================================

    wire [63:0] ex_alu_b;

    assign ex_alu_b =
        ex_alu_src ? ex_imm_ext : ex_rs2_fwd;


    // =================================================================
    // 64-BIT ALU
    // =================================================================

    wire [63:0]  ex_alu_result;
    wire [127:0] ex_mul_full;
    wire         ex_zero;


    alu_64bit u_alu (
        .a       (ex_rs1_fwd),
        .b       (ex_alu_b),
        .acc_in  (ex_acc_fwd),
        .alu_op  (ex_alu_op),

        .result  (ex_alu_result),
        .mul_full(ex_mul_full),
        .zero    (ex_zero)
    );


    // =================================================================
    // BRANCH / JUMP
    // =================================================================

    assign branch_taken =
        ex_jump ||
        (ex_branch_beq && ex_zero) ||
        (ex_branch_bne && !ex_zero);


    assign branch_target =
        ex_pc + 32'd4 + ex_imm_ext[31:0];


    // =================================================================
    // EX / MEM PIPELINE REGISTER
    // =================================================================

    wire [63:0] mem_alu_result;
    wire [63:0] mem_store_data;

    wire [4:0] mem_rd_addr;

    wire mem_reg_write;
    wire mem_mem_read;
    wire mem_mem_write;
    wire mem_mem_to_reg;
    wire mem_halt;


    ex_mem_reg u_ex_mem (
        .clk            (clk),
        .rst            (rst),

        .alu_result_in  (ex_alu_result),
        .store_data_in  (ex_rs2_fwd),

        .rd_addr_in     (ex_rd_addr),

        .reg_write_in   (ex_reg_write),

        .mem_read_in    (ex_mem_read_cur),
        .mem_write_in   (ex_mem_write),
        .mem_to_reg_in  (ex_mem_to_reg),

        .halt_in        (ex_halt),

        .alu_result_out (mem_alu_result),
        .store_data_out (mem_store_data),

        .rd_addr_out    (mem_rd_addr),

        .reg_write_out  (mem_reg_write),

        .mem_read_out   (mem_mem_read),
        .mem_write_out  (mem_mem_write),
        .mem_to_reg_out (mem_mem_to_reg),

        .halt_out       (mem_halt)
    );


    // -----------------------------------------------------------------
    // EX/MEM forwarding information
    // -----------------------------------------------------------------

    assign ex_mem_reg_write_cur  = mem_reg_write;
    assign ex_mem_rd_addr_cur    = mem_rd_addr;
    assign ex_mem_alu_result_cur = mem_alu_result;


    // =================================================================
    // MEM - DATA MEMORY
    // =================================================================

    wire [63:0] mem_rdata;


    data_memory u_dmem (
        .clk       (clk),

        .mem_write (mem_mem_write),
        .mem_read  (mem_mem_read),

        .addr      (mem_alu_result[31:0]),
        .wdata     (mem_store_data),

        .rdata     (mem_rdata)
    );


    // =================================================================
    // MEM / WB PIPELINE REGISTER
    // =================================================================

    wire [63:0] wb_alu_result;
    wire [63:0] wb_mem_data;

    wire        wb_mem_to_reg;
    wire        wb_halt;


    mem_wb_reg u_mem_wb (
        .clk            (clk),
        .rst            (rst),

        .alu_result_in  (mem_alu_result),
        .mem_data_in    (mem_rdata),

        .rd_addr_in     (mem_rd_addr),

        .reg_write_in   (mem_reg_write),

        .mem_to_reg_in  (mem_mem_to_reg),

        .halt_in        (mem_halt),

        .alu_result_out (wb_alu_result),
        .mem_data_out   (wb_mem_data),

        .rd_addr_out    (wb_rd_addr),

        .reg_write_out  (wb_reg_write),

        .mem_to_reg_out (wb_mem_to_reg),

        .halt_out       (wb_halt)
    );


    // -----------------------------------------------------------------
    // MEM/WB forwarding information
    // -----------------------------------------------------------------

    assign mem_wb_reg_write_cur = wb_reg_write;
    assign mem_wb_rd_addr_cur   = wb_rd_addr;


    // =================================================================
    // WB - WRITE BACK
    // =================================================================

    assign wb_data =
        wb_mem_to_reg ? wb_mem_data : wb_alu_result;


    // =================================================================
    // HALT
    // =================================================================

    reg halted;


    always @(posedge clk or posedge rst) begin

        if (rst) begin
            halted <= 1'b0;
        end

        else if (ex_halt) begin
            halted <= 1'b1;
        end

    end


endmodule
