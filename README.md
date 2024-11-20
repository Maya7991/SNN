# Spiking Neural Network Accelerator in a Heterogeneous System with CNN and SNN
This repository contains the VHDL implementation and associated resources for a Spiking Neural Network (SNN) inference accelerator, developed as part of a Master’s project. The project explores the complementary properties of SNNs and CNNs, leveraging their respective strengths for low-power applications on edge devices.

### Dependencies
- VHDL 2008: The project is implemented in VHDL'08 and requires tools that support this standard.
- Simulation Tools: ModelSim, GHDL, or any VHDL simulator that supports VHDL'08.

### Goals
- Implement an SNN inference module in VHDL for energy-efficient inference.
- Leverage PyTorch and SnnTorch for training the model and preparing quantized weights for hardware.

More information is available in the respective folder's Readme files.

### References
The project builds on research in spiking neural networks, hybrid architectures, and energy-efficient hardware. Key references include:

- Eshraghian et al., Training Spiking Neural Networks Using Lessons From Deep Learning, IEEE, 2023.
- Kim et al., C-DNN: Complementary Deep Neural Network Processor, IEEE Journal of Solid-State Circuits, 2024.