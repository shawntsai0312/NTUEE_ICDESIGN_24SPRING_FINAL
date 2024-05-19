module interpolation (
    input           clk,
    input           RST,
    input           START,
    input   [5:0]   H0,
    input   [5:0]   V0,
    input   [3:0]   SW,
    input   [3:0]   SH,
    output          REN,
    input   [7:0]   R_DATA,
    output  [11:0]  ADDR,
    output  [7:0]   O_DATA,
    output          O_VALID
);
// State definition
    parameter S_IDLE  = 3'd0;   // 1 cycle
    parameter S_START = 3'd1;   // 1 cycle
    parameter S_CALC  = 3'd2;   // case by case
    parameter S_ASK4  = 3'd3;   // 5 cycles
    parameter S_ASK2  = 3'd4;   // 3 cycles
    parameter S_FINISH= 3'd5;   // 1 cycle

// Input registers
    reg [5:0] h0, h0_next;
    reg [5:0] v0, v0_next;
    reg [3:0] sw, sw_next;
    reg [3:0] sh, sh_next;

// State register
    reg [2:0] state, state_next;

// Counter register, counter for state machine
    reg [2:0] counter, counter_next;

// Ouput registers
    reg ren, ren_next;
    reg [11:0] addr, addr_next;
    reg [7:0] o_data, o_data_next;
    reg o_valid, o_valid_next;

    assign REN = ren;
    assign ADDR = addr;
    assign O_DATA = o_data;
    assign O_VALID = o_valid;

// output pixel index register, both range from 0 to 16
    reg [4:0] o_h_index, o_h_index_next;
    reg [4:0] o_v_index, o_v_index_next;

// left, right interpolation register
    reg [7:0] left, left_next;
    reg [7:0] right, right_next;

// need ask2
    wire need_ask2;
    Need_ask2 need_ask2_inst(
        .o_h_index(o_h_index),
        .sw(sw),
        .need_ask2(need_ask2)
    );

// edge
    wire [3:0] i_h_index, i_v_index, i_v_next_index;
    Edge edge_h(
        .current_index(o_h_index),
        .size(sw),
        .out(i_h_index)
    );
    Edge edge_v(
        .current_index(o_v_index),
        .size(sh),
        .out(i_v_index)
    );
    Edge edge_v_next(
        .current_index(o_v_index + 5'b1),
        .size(sh),
        .out(i_v_next_index)
    );

// interpolate2
    wire [7:0] left_interpolate, right_interpolate, middle_interpolate;
    Interpolate2 left_interpolate_inst(
        .o_index(o_v_index),
        .i_index(i_v_index),
        .size(sh),
        .A(left),
        .B(R_DATA),
        .out(left_interpolate)
    );
    Interpolate2 right_interpolate_inst(
        .o_index(o_v_index),
        .i_index(i_v_index),
        .size(sh),
        .A(right),
        .B(R_DATA),
        .out(right_interpolate)
    );
    Interpolate2 middle_interpolate_inst(
        .o_index(o_h_index),
        .i_index(i_h_index),
        .size(sw),
        .A(left),
        .B(right),
        .out(middle_interpolate)
    );

// Input register update
    always @(*) begin
        h0_next = h0;
        v0_next = v0;
        sw_next = sw;
        sh_next = sh;
        if (START) begin
            h0_next = H0;
            v0_next = V0;
            sw_next = SW;
            sh_next = SH;
        end
    end

// State machine
    always @(*) begin
        state_next = state;
        case (state)
            S_IDLE: begin
                if (START)  state_next = S_START;
                else        state_next = S_IDLE;
            end
            S_START: state_next = S_ASK4;
            S_CALC: begin
                if(o_h_index == 15) begin
                    if(o_v_index == 16) state_next = S_FINISH;
                    else                state_next = S_ASK4;
                end
                else if(need_ask2 == 1) state_next = S_ASK2;
                else                    state_next = S_CALC;
            end
            S_ASK4: begin
                if(counter == 4)    state_next = S_CALC;
                else                state_next = S_ASK4;
            end
            S_ASK2: begin
                if(counter == 2)    state_next = S_CALC;
                else                state_next = S_ASK2;
            end
            S_FINISH: state_next = S_IDLE;
            default: state_next = state;
        endcase
    end

// counter logic
    always @(*) begin
        counter_next = 3'b0;
        case (state)
            S_ASK4: if(counter < 4) counter_next = counter + 1;
            S_ASK2: if(counter < 2) counter_next = counter + 1;
            default: counter_next = 3'b0;
        endcase
    end

// output horizontal pixel index logic
    always @(*) begin
        o_h_index_next = o_h_index;
        case (state)
            S_IDLE: o_h_index_next = 5'b0;
            S_CALC: if(o_h_index < 16)                  o_h_index_next = o_h_index + 1;
            S_ASK4: if(counter == 0 && o_h_index == 16) o_h_index_next = 5'b0;
            default: o_h_index_next = o_h_index;
        endcase
    end

// output vertical pixel index logic
    always @(*) begin
        o_v_index_next = o_v_index;
        case (state)
            S_IDLE: o_v_index_next = 5'b0;
            S_ASK4: if(counter == 0 && o_h_index == 16) o_v_index_next = o_v_index + 1;
            default: o_v_index_next = o_v_index;
        endcase
    end

// ask data logic
    reg [5:0] h_ask, v_ask;
    always @(*) begin
        h_ask = 7'b0;
        v_ask = 7'b0;
        ren_next = 1'b1;
        addr_next = addr;
        case (state)
            S_START: begin
                // go to ask4 and ask for LT pixel
                ren_next = 1'b0;
                h_ask = h0;
                v_ask = v0;
            end
            S_CALC: begin
                if(o_h_index == 15) begin
                    if(o_v_index < 16) begin
                        // go to ask4 and ask for LT pixel
                        ren_next = 1'b0;
                        h_ask = h0;
                        v_ask = v0 + i_v_next_index - 1;
                    end
                end
                else if(need_ask2 == 1) begin
                    // go to ask2 and ask for RT pixel
                    ren_next = 1'b0;
                    h_ask = h0 + i_h_index + 1;
                    v_ask = v0 + i_v_index - 1;
                end
            end
            S_ASK4: begin
                case(counter)
                    0: begin
                        // ask for LB pixel
                        if(o_v_index == 15) begin
                            ren_next = 1'b0;
                            h_ask = h0;
                            v_ask = v0 + sh - 1;
                        end
                        else begin
                            ren_next = 1'b0;
                            h_ask = h0;
                            v_ask = v0 + i_v_next_index;
                        end
                    end
                    1: begin
                        // ask for RT pixel
                        ren_next = 1'b0;
                        h_ask = h0 + 1;
                        v_ask = v0 + i_v_index - 1;
                    end
                    2: begin
                        // ask for RB pixel
                        ren_next = 1'b0;
                        h_ask = h0 + 1;
                        v_ask = v0 + i_v_index;
                    end
                endcase
            end
            S_ASK2: begin
                if(counter == 0)begin
                    // ask for RB pixel
                    ren_next = 1'b0;
                    h_ask = h0 + i_h_index;
                    v_ask = v0 + i_v_index;
                end
            end
            default: begin
                ren_next = 1'b1;
                h_ask = 7'b0;
                v_ask = 7'b0;
            end
        endcase
        addr_next = h_ask + (v_ask << 6);
    end

// load data, left interpolation logic
    always @(*) begin
        left_next = left;
        case (state)
            S_ASK4: begin
                case(counter)
                    1: left_next = R_DATA; // get LT pixel
                    2: left_next = left_interpolate; // get LB pixel and calculate
                endcase
            end
            S_ASK2: if(counter == 1) left_next = right; // get RT pixel
            default: left_next = left;
        endcase
    end

// load data, right interpolation logic
    always @(*) begin
        right_next = right;
        case (state)
            S_ASK4: begin
                case(counter)
                    3: right_next = R_DATA; // get RT pixel
                    4: right_next = right_interpolate; // get RB pixel and calculate
                endcase
            end
            S_ASK2: begin
                case(counter)
                    1: right_next = R_DATA; // get RT pixel
                    2: right_next = right_interpolate; // get RB pixel and calculate
                endcase
            end
            default: right_next = right;
        endcase
    end

// output logic
    always @(*) begin
        o_valid_next = 1'b0;
        o_data_next = o_data;
        case (state)
            S_CALC: begin
                o_valid_next = 1'b1;
                o_data_next = middle_interpolate;
            end
            S_ASK4: begin
                if(counter == 0 && o_h_index == 16) begin
                    o_valid_next = 1'b1;
                    if(sw == 1) o_data_next = left;
                    else        o_data_next = right;       
                end
            end
            S_FINISH: begin
                o_valid_next = 1'b1;
                if(sw == 1) o_data_next = left;
                else        o_data_next = right; 
            end
            default: begin
                o_valid_next = 1'b0;
                o_data_next = o_data;
            end
        endcase
    end

// State register update
    always @(posedge clk or posedge RST) begin
        if (RST) begin
            h0 <= 6'b0;
            v0 <= 6'b0;
            sw <= 4'b0;
            sh <= 4'b0;

            state <= S_IDLE;
            counter <= 3'b0;

            o_h_index <= 5'b0;
            o_v_index <= 5'b0;

            left <= 8'b0;
            right <= 8'b0;

            ren <= 1'b1;
            addr <= 12'b0;

            o_valid <= 1'b0;
            o_data <= 8'b0;
        end else begin
            h0 <= h0_next;
            v0 <= v0_next;
            sw <= sw_next;
            sh <= sh_next;

            state <= state_next;
            counter <= counter_next;

            o_h_index <= o_h_index_next;
            o_v_index <= o_v_index_next;

            left <= left_next;
            right <= right_next;

            ren <= ren_next;
            addr <= addr_next;

            o_valid <= o_valid_next;
            o_data <= o_data_next;
        end
    end
endmodule

module Need_ask2 (
    input [4:0] o_h_index,
    input [3:0] sw,
    output need_ask2
);
    wire [3:0] edgeNext, edgeCurr;
    Edge edge_next(
        .current_index(o_h_index + 5'b1),
        .size(sw),
        .out(edgeNext)
    );
    Edge edge_curr(
        .current_index(o_h_index),
        .size(sw),
        .out(edgeCurr)
    );
    assign need_ask2 = (edgeNext > edgeCurr) ? 1'b1 : 1'b0;
endmodule

module Edge (
    input [4:0] current_index,
    input [3:0] size,
    output [3:0] out
);
    assign out = (current_index == 16) ? size - 4'b1 : ((current_index * (size - 1)) >> 4) + 4'b1;
endmodule

module Interpolate2 (
    input [4:0] o_index,
    input [3:0] i_index,
    input [3:0] size,
    input [7:0] A,
    input [7:0] B,
    output [7:0] out
);
    wire [11:0] temp;
    assign temp = (B << 4) + ((i_index << 4) - o_index * (size - 4'b1)) * (A - B);
    assign out = temp >> 4;
    // (( B << 4) + (( i_index << 4) -   o_index * (size - 1)) * (A - B)) >> 4;
endmodule