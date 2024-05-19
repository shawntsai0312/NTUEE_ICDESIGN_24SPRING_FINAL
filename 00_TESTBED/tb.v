`timescale 1ns/1ps

`default_nettype none

`define CLK_PERIOD 5.0
`define MAX_CYCLE 100000

// ==================== DO NOT MODIFY ====================
`define DEL 1.0
`define ROM_SIZE 64*64
`define OUT_SIZE 17*17

`ifdef P0
    `define ROM_FILE "./../00_TESTBED/P0/rom.dat"
    `define PARAM_FILE "./../00_TESTBED/P0/param.dat"
    `define GOLDEN_FILE "./../00_TESTBED/P0/golden.dat"
`elsif P1
    `define ROM_FILE "./../00_TESTBED/P1/rom.dat"
    `define PARAM_FILE "./../00_TESTBED/P1/param.dat"
    `define GOLDEN_FILE "./../00_TESTBED/P1/golden.dat"
`elsif P2
    `define ROM_FILE "./../00_TESTBED/P2/rom.dat"
    `define PARAM_FILE "./../00_TESTBED/P2/param.dat"
    `define GOLDEN_FILE "./../00_TESTBED/P2/golden.dat"
`elsif P3
    `define ROM_FILE "./../00_TESTBED/P3/rom.dat"
    `define PARAM_FILE "./../00_TESTBED/P3/param.dat"
    `define GOLDEN_FILE "./../00_TESTBED/P3/golden.dat"
`else 
    `define ROM_FILE "./../00_TESTBED/P1/rom.dat"
    `define PARAM_FILE "./../00_TESTBED/P1/param.dat"
    `define GOLDEN_FILE "./../00_TESTBED/P1/golden.dat"
`endif

`define NUM_OF_PATTERN 10
// ==================== DO NOT MODIFY ====================


`ifdef SYN
    `define SDFFILE "./interpolation_syn.sdf"
`elsif APR
    `define SDFFILE "./layout/interpolation_apr.sdf"
`endif


module tb;

integer i=0, j=0, error_cnt=0;

reg             CLK = 0;
reg             RST = 0;
reg             START = 0;
reg     [5:0]   V0;
reg     [5:0]   H0;
reg     [3:0]   SW;
reg     [3:0]   SH;
wire            REN;
reg     [7:0]   R_DATA;
wire    [11:0]  ADDR;
wire    [7:0]   O_DATA;
wire            O_VALID;

reg             can_start = 1;
reg             REN_buf;
reg     [11:0]  ADDR_buf;
reg     [7:0]   R_DATA_buf;

reg     [7:0]   ROM_SIM [0:`ROM_SIZE];
reg     [6:0]   PARAM [0:`NUM_OF_PATTERN*4];
reg     [7:0]   GOLDEN_DATA [0:`NUM_OF_PATTERN*`OUT_SIZE];

always #(`CLK_PERIOD/2) CLK=~CLK;

initial begin
    
    $readmemh (`ROM_FILE, ROM_SIM);
    $readmemh (`PARAM_FILE, PARAM);
    $readmemh (`GOLDEN_FILE, GOLDEN_DATA);
end

initial begin
    $fsdbDumpfile("tb.fsdb");
    $fsdbDumpvars(0, tb, "+mda");
end

initial begin
    @(posedge CLK);
    #(`DEL)
    RST = 1;
    #(`CLK_PERIOD * 2.0)
    RST = 0;
    while (i < `NUM_OF_PATTERN) begin
        if (can_start) begin
            START = 1;
            can_start = 0;
        end
        else START = 0;
        #(`CLK_PERIOD);
    end
end


initial begin
    @(posedge CLK) #(`DEL);
    while (i < `NUM_OF_PATTERN*`OUT_SIZE) begin
        R_DATA = R_DATA_buf;
        #(`CLK_PERIOD);
    end
end
initial begin
    @(posedge CLK) #(`CLK_PERIOD-`DEL);
    while (i < `NUM_OF_PATTERN*`OUT_SIZE) begin
        REN_buf = REN;
        ADDR_buf = ADDR;
        #(`CLK_PERIOD);
    end
end
always @(posedge CLK) begin
    if (~REN_buf) begin
        R_DATA_buf = ROM_SIM[ADDR_buf];
    end
end





always @(*) begin
    H0 = 6'hxx;
    V0 = 6'hxx;
    SW = 6'hxx;
    SH = 6'hxx;
    if (START) begin
        H0 = PARAM[i*4];
        V0 = PARAM[i*4+1];
        SW = PARAM[i*4+2];
        SH = PARAM[i*4+3];
    end
end

interpolation dut (
    .clk        (CLK),
    .RST        (RST),
    .START      (START),
    .H0         (H0),
    .V0         (V0),
    .SW         (SW),
    .SH         (SH),
    .ADDR       (ADDR),
    .R_DATA     (R_DATA),
    .O_DATA     (O_DATA),
    .REN        (REN),
    .O_VALID    (O_VALID)
);

`ifdef RTL
   initial #1 $display("RTL sim do not need any SDFFILE.");
`elsif SYN
   initial $sdf_annotate(`SDFFILE, dut);
   initial #1 $display("SDF File %s were used for this simulation.", `SDFFILE);
`elsif APR
   initial $sdf_annotate(`SDFFILE, dut);
   initial #1 $display("SDF File %s were used for this simulation.", `SDFFILE);
`else 
   initial $sdf_annotate(`SDFFILE, dut);
   initial #1 $display("SDF File %s were used for this simulation.", `SDFFILE);
`endif


initial begin
    @(posedge CLK) #(`CLK_PERIOD-`DEL);
    while (i < `NUM_OF_PATTERN) begin
        if (O_VALID) begin
            if (O_DATA !== GOLDEN_DATA[(i*`OUT_SIZE)+j]) begin
                if (error_cnt < 20) begin
                    $display("pattern[%0d][%0d] error, your value: %0h, golden value: %0h", i, j, O_DATA, GOLDEN_DATA[(i*`OUT_SIZE)+j]);
                    if (error_cnt == 19) begin
                        $display("There are at least 20 errors, further error will not be printed");
                    end
                end
                error_cnt = error_cnt + 1;
            end else begin
                // $display("pattern[%0d][%0d] ** Correct!! ** ", i, j, O_DATA, GOLDEN_DATA[(i*`OUT_SIZE)+j]);
            end

            if (j == `OUT_SIZE-1) begin
                i = i + 1;
                j = 0;
                can_start = 1;
            end else begin
                j = j + 1;
            end
        end
        #(`CLK_PERIOD);
    end
    if (error_cnt == 0) begin
        $display("\n");
        $display("================================= The test result is ..... PASS =================================");
        $display("                                           .:----::.                                             ");
        $display("                                    .--+*#****##X##+=---:.                                       ");
        $display("                                    :=+*#XXX#XX@@@@@@@@X@XXXX#*+-.                               ");
        $display("                                .=#XXXXXXXXXXXXXXXXXXX@@@@@@XXX##+:.                             ");
        $display("                            -*XXXXX@XXXXX###XX#XXXXXXX@@@@@XXX#*=:.                              ");
        $display("                            -#XXXXXXXXXX###XXXXXXXX#XXXXXX@@@@XXXXXXXX#+-.                       ");
        $display("                        -#XXX@@@XXXXXX@XXXXX######XXXXX@@@@@@XXXX@XXXXXX*:                       ");
        $display("                        .*@X@@@@@XX@@@@X@@XXXXXXXXXXXX@XX@@@@@@XXXX@@@@XXXXX*.                   ");
        $display("                        +@@@@@@@@@@XXXXXX@XXX###XXXXXXXXXXXXXXXXXXXX@@@@@@XXXXX=                 ");
        $display("                    :#@@@@@@@@XXXXXXX@@XXX#XXXXXXXX####XXXXXX#XXXXXX@@@XXXXXXX*.                 ");
        $display("                    =X@@@@@@@@XX@@XX@@XXX@XXXXXXXX#*######*#**#####XXXXX@XXXXXXX#.               ");
        $display("                    +X@@@@@@@@@@@@@@@@@@@XX###***+++++++++=++++++*+#*#XX@XXXXXXXXX#:             ");
        $display("                +@@@@@@@@@@@@@@@X@@XX#**+====--==----------====*===*XX@XXXXXXXXX#:               ");
        $display("                +@@@@@@@@@@@@@@@@XX#*+==-----------:::-:-----==+-==-=*XXXXXXXXXXX##.             ");
        $display("                -@@@@@@@@@@@@@@XX#*+==---------::::::::::::----=------=*XX@XXXXXXXXX*            ");
        $display("                :X@@@@@@@@@@@@X#*+==-----::::::::::::::::::::----::-----=*X@XXXXXXXXX#=          ");
        $display("                X@@@@@@@@@@@XX*+===-----::::::::::::::::::::::-:::::-----+#XX@X##XXXX#*.         ");
        $display("            +@@@@@@@@@@X##*+==------:::::::::::::::...:::::::::::-----=*XX@XX###XXX#-            ");
        $display("            :@@@@@@@@@@X#**+==------::::::::::::::::::::::::::::::::---=*#XXX@X###XX#+           ");
        $display("            #@@@@@@@@@@X#*++==-----::::::::::::..:..:::::::::::::::::--=*#XXXXXXX#XXX+           ");
        $display("            :X@@@@@@@@@X#*++==--------::::::::........:::::.::::::::::---+#XXXXXXXX#XX*          ");
        $display("            +X@@@@@@@@@X#*++==--------:::::::............:...:.:::::::--=+#XXXXXXXX##X#:         ");
        $display("            *@@@@@@@@@@X##++==--------::::::::.::::::.:::...:..:::::::--=+#XXXXXXX#X#XX=         ");
        $display("            *@@X@@@@@@@XX**++==------::::::::::.::::.............:::::---+*#XXXXXXXX#X#*.        ");
        $display("            +@@@@@@@@@@XX**++==-------::::::......::.........:::::::::---=*#XXXXXX##XX##-        ");
        $display("            =@@@@@@@@@@@#*+++====-=----:::::................::::-----::---+#XXXXXX######=        ");
        $display("            =@@@@@@@@@@X**++++++++++===--:::::....::::.:::-======---==-----###XXXXX###**=        ");
        $display("            =@@@@@@X@@@#*++++**++++++++++==-:::.::::::::--==---::--:-------+#X#XXXX##++=:        ");
        $display("            -XX@@@@X@@X#*++**++==-:::::--==--::::::::::-::::::...::::------=#XXXXXX##*:.         ");
        $display("            .#*XX@@@@@X**+++++==--======--=---::::::::::--=++++==:::::::-:--#XX#X####+:          ");
        $display("            -=#*X@@XXX*+++++=--==*+#XX#+=-:---::...:----=+###X+++=-::::::-=**#**+=X+:            ");
        $display("            :-*##XX**++*==+=++**+=X##X-*+=--=----:::--=+-*#X#--=+=--=--+=-*#+----#+.             ");
        $display("                .****XXX*+*+=+=+**+==**+=--=-=+==:..:-=---===--:::--==-+-----*##-::-=:           ");
        $display("                .=+++#XX++++=+===++=-------:-====:..:-=-:---=------:----::::-=**=::::            ");
        $display("                +++#XX++++====---------:::--==-::.::--::::::::::::---:::::-=++=:::.              ");
        $display("                ++*##X++++==--=-=-:::::------=-:::.:.::-::-:::::--:....:::---==:::               ");
        $display("                -++*##+++==---::::----::::::-=-::.:::..:::::::::.......::::----::.               ");
        $display("                .++***+++==--:::::::::.::::-==-::.:::..................::::-::::::               ");
        $display("                ++**+++++=--::::::::....:-===-:...:::::...............:::--:::::.                ");
        $display("                =+**+++++=---::::::....:-===--:...:::::::...........:::::--::::-                 ");
        $display("                -++++++++==---::::.....:====--:...:::::::::........::::::--::::.                 ");
        $display("                    =++=++++===---::::...:===-==-::::-=::::::::......:::::::--:::.               ");
        $display("                    =+++++++==----:::::.:-++=**+=-----=-::.::::::.:::::::::--:::                 ");
        $display("                    .+++++++===---::::.::---====---:::::::..:::::::::::::::-:::.                 ");
        $display("                    :++=+++====---::::::-------:::::::::::....::::::::::::-:.                    ");
        $display("                    .:=+++=====--:::::-------:::::.:::::::::...:::::::::--                       ");
        $display("                        ==++====---:::-----------:--::::::::::::..::::::--:                      ");
        $display("                        .+++====---:::--=================---::::.:.::::::-.                      ");
        $display("                        -++=====--:::-=****+=+=----========-:::..:::::--:                        ");
        $display("                            =+=====--::::-=+++=----:-::-----:::::::::::::--                      ");
        $display("                            .++=====--::::-====----::::::::::..:::::::::--.                      ");
        $display("                            .=======----:----------::::::.....:::::::::-:                        ");
        $display("                            .=======----------::::::...:::::.:::::::---X=                        ");
        $display("                            .==+=====--------:::::.......:::::::::----X#-                        ");
        $display("                                .+=======------:::::::.....:::::---------XX#:                    ");
        $display("                                +++++++===-----::::::::::::::::----==----@X#*                    ");
        $display("                            =X#+++++++===-----:::::::::::::---===-----@XX#-                      ");
        $display("                            .X@X+++++++++===-----::::-:-----====---::--X@X#*                     ");
        $display("                            *@@@+++++++++++=====------=======-----:::--#XX##*=:                  ");
        $display("                            :@@@@#+++++++++++++===+++++++===------::::--+XX##*##+.               ");
        $display("                            :#@@@@X*++++++++++++++++++====-----:::::::::--XX#######-             ");
        $display("                        :-XX@@@@X**++++++++++=====---------:::::::::::--X#########::-.           ");
        $display("                    ..:+*+#XX@@@@X**+++++++++=====-----::::::::::::::::-+X#########* :=+=-:      ");
        $display("                .:-+*#**=@XX@@@@@**+++++++++======--::::::::::::::::::-*X##########::=====:      ");
        $display("            ..-=+****+++@@X@@@@@#*+++===========---::::::::::::::::::=############=.:.  .:----:. ");
        $display("            .:=++++-::-+*=#@@X@@XX@X*+++========-----::::::::::::::::::-*#X##########*  .        ");
        $display("    ...::::::::::::::-:@@@XX@XXXX#+++===-=====---:::::::::::::::::::=##X##########*  .           ");
        $display(".:...............::::::--=@@@@X@XXXX#*++===-------------::::::::::::::-*#X###########* :==+-.    ");
        $display("+=+++===--:::.....:-+*++:+@@@@X@XXXX#*+====---------:::::::::::::::::-+*X###XX#######+ =--:-=====");
        $display("=-=------=+==++++++===++.*@@@@@@XXXX#++====--------:::::::::::::::::-=*####XXX#######= ==-:--====");
        $display("+========---=======--==* #X@@@@@XXXXX*======----::::::::::::::::::::=+####X##X######X::=:-++++++=");
        $display("....::--==+++*+++++++**: #XX@@@@@XXXXX*=====---::::::::::::...::.::-=#X###XX#X####### .        ..");
        $display("    .  ...       .   :: #XX@@@@@@XXXXX#=------::::::::::::......:-=*X####XXX#######+             ");
        $display("        ...    .  .:: XXXXX@@@@@XXXXXX*-----:::::::::........:-=*X####XXX#######X-               ");
        $display("::.               .  .:: XXXXXX@@@@@XXXXXXX#=::.-=.:...........:--=#####XXX########*.--:         ");
        $display("==+*********++-:..::--+=.XXXXXXXX@@@XXXX#=::=*##*=:::.:......::-+:**####XX########X.:-=+**++++===");
        $display("++==-:::------==+++=--=+.XXXXXXXXX@XX###=**###*==++:::::....::-:*=*XXXX##########*+++=-::::::::--");
        $display("------:::::::::-====+==+-*XXXXXX##*+==-+*+*#*##++=+*-:::..::-:--=+=++*******#**====--:::::::::-:-");
        $display("-==++******###**+=--==+*##XXXX##*+++++++*=+*#*+*=--:.::::::-*-=-.-============------=++*****++==-");
        $display("\n");
        $display("                     *************************************************            ");
        $display("                     **                                             **      /|____|\\");
        $display("                     **             Congratulations !!              **    ((´-___- `))");
        $display("                     **                                             **   ///        \\\\\\");
        $display("                     **  All data have been generated successfully! **  /||          ||\\");
        $display("                     **                                             **  w|\\ m      m /|w");
        $display("                     *************************************************    \\(o)____(o)/");
        $display("\n");
        $display("=================================================================================================");
    end else begin
        $display("===============================================");
        $display("              There are %0d errors.            ", error_cnt);
        $display("===============================================");
    end
    $finish;

end



initial begin
    #(`CLK_PERIOD * `MAX_CYCLE);
    $display("===============================================");
    $display("                   Over time                   ");
    $display("===============================================");
    #(`CLK_PERIOD);
    $finish;
end



endmodule
`default_nettype wire

