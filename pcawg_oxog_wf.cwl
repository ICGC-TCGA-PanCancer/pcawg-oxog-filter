#!/usr/bin/env cwl-runner
cwlVersion: v1.0

doc: |
    This workflow will perform OxoG filtering on a set of VCFs. It will produce VCFs and their associated index files.

requirements:
    - class: SchemaDefRequirement
      types:
          - $import: PreprocessedFilesType.yaml
          - $import: TumourType.yaml
    - class: ScatterFeatureRequirement
    - class: StepInputExpressionRequirement
    - class: MultipleInputFeatureRequirement
    - class: InlineJavascriptRequirement
      expressionLib:
        - { $include: oxog_util.js }
    - class: SubworkflowFeatureRequirement


class: Workflow
outputs:
    oxogVCFs:
        outputSource: flatten_oxog_output/oxogVCFs
        type: File[]
    oxogTBIs:
        outputSource: flatten_oxog_tbi_output/oxogTBIs
        type: File[]
inputs:
    inputFileDirectory:
      type: Directory
    refFile:
      type: File
    out_dir:
      type: string
    refDataDir:
      type: Directory
    # "tumours" is an array of records. Each record contains the tumour ID, BAM
    # file name, and an array of VCFs.
    tumours:
      type:
        type: array
        items: "TumourType.yaml#TumourType"

steps:
    preprocess_files:
        run: preprocessor_for_oxog.cwl
        in:
            vcfdir: inputFileDirectory
            ref: refFile
            out_dir: out_dir
            filesToPreprocess:
                source: [ tumours ]
                valueFrom: |
                    ${
                        // Put all VCFs into an array.
                        var VCFs = []
                        for (var i in self)
                        {
                            for (var j in self[i].associatedVcfs)
                            {
                                VCFs.push(self[i].associatedVcfs[j])
                            }
                        }
                        return VCFs;
                        //return self[0].associatedVcfs
                    }
        out: [preprocessedFiles]

    get_extracted_snvs:
        in:
            in_record: preprocess_files/preprocessedFiles
        run:
            class: ExpressionTool
            inputs:
                in_record: "PreprocessedFilesType.yaml#PreprocessedFileset"
            outputs:
                extracted_snvs: File[]?
            expression: |
                $( { extracted_snvs:  inputs.in_record.extractedSnvs } )
        out: [extracted_snvs]

    get_cleaned_vcfs:
        in:
            in_record: preprocess_files/preprocessedFiles
        run:
            class: ExpressionTool
            inputs:
                in_record: "PreprocessedFilesType.yaml#PreprocessedFileset"
            outputs:
                cleaned_vcfs: File[]
            expression: |
                $( { cleaned_vcfs:  inputs.in_record.cleanedVcfs } )
        out: [cleaned_vcfs]

    ### Prepare for OxoG!
    # First we need to zip and index the VCFs - the OxoG filter requires them to
    # be zipped and index.
    zip_and_index_files_for_oxog:
        in:
            vcf:
                source: get_cleaned_vcfs/cleaned_vcfs
        scatter: [vcf]
        out: [zipped_file]
        run: zip_and_index_vcf.cwl

    # Gather the appropriate VCFS.
    # All SNVs, and all SNVs extracted from INDELs.
    gather_vcfs_for_oxog:
        in:
            vcf:
                source: [zip_and_index_files_for_oxog/zipped_file]
                valueFrom: |
                    ${
                        var snvs = []
                        for (var i in self)
                        {
                            if (self[i].basename.indexOf("snv") !== -1)
                            {
                                snvs.push(self[i])
                            }
                        }
                        return snvs
                    }
            extractedSNVs:
                source: get_extracted_snvs/extracted_snvs
        run:
            class: ExpressionTool
            inputs:
                vcf: File[]
                extractedSNVs: File[]?
            outputs:
                vcfs: File[]
            expression: |
                $(
                    { vcfs: inputs.vcf.concat(inputs.extractedSNVs) }
                )
        out: [vcfs]

    ########################################
    # Do OxoG Filtering                    #
    ########################################
    #
    # OxoG only runs on SNV VCFs
    run_oxog:
        in:
            in_data:
                source: tumours
            inputFileDirectory: inputFileDirectory
            refDataDir: refDataDir
            vcfsForOxoG: gather_vcfs_for_oxog/vcfs
        out: [oxogVCF, oxogTBI]
        scatter: [in_data]
        run: oxog_sub_wf.cwl

    flatten_oxog_output:
        in:
            array_of_arrays: run_oxog/oxogVCF
        run:
            class: ExpressionTool
            inputs:
                array_of_arrays:
                    type: { type: array, items: { type: array, items: File } }
            expression: |
                $(
                    { oxogVCFs: flatten_nested_arrays(inputs.array_of_arrays) }
                )
            outputs:
                oxogVCFs: File[]
        out:
            [oxogVCFs]

    flatten_oxog_tbi_output:
        in:
            array_of_arrays: run_oxog/oxogTBI
        run:
            class: ExpressionTool
            inputs:
                array_of_arrays:
                    type: { type: array, items: { type: array, items: File } }
            expression: |
                $(
                    { oxogTBIs: flatten_nested_arrays(inputs.array_of_arrays) }
                )
            outputs:
                oxogTBIs: File[]
        out:
            [oxogTBIs]
