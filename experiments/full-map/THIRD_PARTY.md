# Sources and licenses

The preview code uses the repository's MIT license.

The brain data comes from [MaleCNS v1.0](https://male-cns.janelia.org/download/):
HHMI Janelia FlyEM, University of Cambridge, MRC Laboratory of Molecular Biology, and Google Research.
The data retains [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
The data pack changes the format, selects classified neurons, assigns display groups, and selects input/output cells.
The pack includes a notice and file hashes. It is distributed in GitHub Releases.

The model equations and parameter values follow [Shiu et al. (2024)](https://www.nature.com/articles/s41586-024-07763-9).
The [authors' reference implementation](https://github.com/philshiu/Drosophila_brain_model) is MIT licensed,
copyright 2023 Philip Shiu and Nico Spiller. This package implements the equations in Swift, C++, and Metal.
It does not bundle or execute the authors' Python code.
The source graph, stimulus adapter, time step, and validation scope differ. See the model notes.

The desktop recording draws its own windows and wallpaper. It does not capture the user's desktop.
The fly sprite is the repository's vector drawing.
