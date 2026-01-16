# deconvolution_project
Repository for deconvolution analysis via unfold

Paper Title: Using Deconvolution to Understand Cognitive Processes in Reading and Language Comprehension
(included in repo)

# Summary
In an EEG experiment, observed signals are the result of synced underlying processes in the brain, and these processes (in research) are triggered by the experiment's design.
To make conclusions on what processes are active during reading, we need the ability to model potential factors and predictors that can explain the observed neural activity 
averaged across participants. Deconvolution allows us to model the EEG signal we see as a "sum" of other signals: signals that which are independent of each other, each modeling the contribution of 
a predictor to the overall waveform. In this project, we show that this approach (computationally done using "unfold" in MATLAB, a linear regression based deconvolution toolbox), 
uncovers hidden details that is masked in the summed nature of the original EEG waveform.

# Future Work
Further work is being done as we migrate the data processing pipeline into Julia, which holds unfold's later features. Understanding the limits of this approach computationally and
methodologically will help our lab revise previous analyses, and expand our toolset of methods.

*Credits for the "unfold" toolbox go to Benedikt Ehinger and Olaf Dimigen.*
