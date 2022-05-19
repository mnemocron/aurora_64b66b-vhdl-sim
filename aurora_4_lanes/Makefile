
GHDL=ghdl
FLAGS="--ieee=synopsys"

all:
	@$(GHDL) -a $(FLAGS) aurora_64b66b_0_frame_check.vhd
	@$(GHDL) -a $(FLAGS) aurora_64b66b_0_frame_gen.vhd
	@$(GHDL) -a $(FLAGS) tb_ghdl.vhd
	@$(GHDL) -e $(FLAGS) aurora_64b66b_0_frame_check
	@$(GHDL) -e $(FLAGS) aurora_64b66b_0_frame_gen
	@$(GHDL) -e $(FLAGS) tb_ghdl
	@$(GHDL) -r $(FLAGS) tb_ghdl --wave=wave.ghw --stop-time=3us
