@echo off
REM ****************************************************************************
REM Vivado (TM) v2024.2.2 (64-bit)
REM
REM Filename    : simulate.bat
REM Simulator   : AMD Vivado Simulator
REM Description : Script for simulating the design by launching the simulator
REM
REM Generated by Vivado on Tue May 13 20:09:27 +0800 2025
REM SW Build 6060944 on Thu Mar 06 19:10:01 MST 2025
REM
REM Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
REM Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
REM
REM usage: simulate.bat
REM
REM ****************************************************************************
REM simulate design
echo "xsim read_tb_behav -key {Behavioral:sim_1:Functional:read_tb} -tclbatch read_tb.tcl -view D:/digital design/Ordovician/Ordovician_a7/SystolicArray_tb_behav.wcfg -log simulate.log"
call xsim  read_tb_behav -key {Behavioral:sim_1:Functional:read_tb} -tclbatch read_tb.tcl -view D:/digital design/Ordovician/Ordovician_a7/SystolicArray_tb_behav.wcfg -log simulate.log
if "%errorlevel%"=="0" goto SUCCESS
if "%errorlevel%"=="1" goto END
:END
exit 1
:SUCCESS
exit 0
