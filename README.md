# pcawg-oxog-filter
The CWL workflow to execute the OxoG filter _only_. For a workflow that runs PCAWG OxoG Filter, PCAWG Annotation, and generates Minibams, see this repository:  https://github.com/ICGC-TCGA-PanCancer/OxoG-Dockstore-Tools

The original SeqWare workflow can be found here: https://github.com/ICGC-TCGA-PanCancer/OxoGWrapperWorkflow
The Seqware workflow runs: the OxoG filter, produces mini-bams, and also runs Jonathan Dursi's PCAWG Annotator.

To visualize _this_ workflow, see here: https://view.commonwl.org/workflows/github.com/ICGC-TCGA-PanCancer/pcawg-oxog-filter/blob/master/pcawg_oxog_wf.cwl

You can run this workflow with this command:
```
$ cwltool --debug --relax-path-checks --non-strict ./pcawg_oxog_wf.cwl ./my_input_file.json > out 2> err &
```
