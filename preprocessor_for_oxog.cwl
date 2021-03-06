#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow

doc: |
    This workflow will perform preprocessing steps on VCFs for the OxoG/Variantbam/Annotation workflow.

dct:creator:
    foaf:name: "Solomon Shorser"
    foaf:mbox: "solomon.shorser@oicr.on.ca"

requirements:
    - class: SchemaDefRequirement
      types:
          - $import: PreprocessedFilesType.yaml
    - class: ScatterFeatureRequirement
    - class: StepInputExpressionRequirement
    - class: MultipleInputFeatureRequirement
    - class: InlineJavascriptRequirement
      expressionLib:
        - { $include: ./preprocess_util.js }
    - class: SubworkflowFeatureRequirement

inputs:
    - id: vcfdir
      type: Directory
      doc: "The directory where the files are"
    - id: filesToPreprocess
      type: string[]
      doc: "The files to process"
    - id: ref
      type: File
      doc: "Reference file, used for normalized INDELs"
    - id: out_dir
      type: string
      doc: "The name of the output directory"

# There are three output sets:
# - The merged VCFs.
# - The VCFs that are cleaned and normalized.
# - The SNVs that were extracted from INDELs (if there were any - usually there are none).
outputs:
    preprocessedFiles:
        type: "PreprocessedFilesType.yaml#PreprocessedFileset"
        outputSource: populate_output_record/output_record

steps:
    # TODO: Exclude MUSE files from PASS-filtering. MUSE files still need to be cleaned, but should
    # not be PASS-filtered.
    pass_filter:
      doc: "Filter out non-PASS lines from the VCFs in filesToProcess."
      in:
        vcfdir: vcfdir
        filesToFilter:
            source: [ filesToPreprocess ]
            valueFrom: |
                ${
                    var VCFs = []
                    for (var i in self)
                    {
                        if (self[i].toLowerCase().indexOf("muse") == -1)
                        {
                            VCFs.push(self[i]);
                        }
                    }
                    return VCFs;
                }
      run: pass-filter.cwl
      out: [output]

    clean:
      doc: "Clean the VCFs."
      run: clean_vcf.cwl
      scatter: [vcf]
      in:
        vcf: pass_filter/output
      out: [clean_vcf]

    gather_muse_snvs_for_cleaning:
      in:
        vcfdir:
            source: vcfdir
        vcfs:
            source: filesToPreprocess
      out: [snvs_for_cleaning]
      run:
        class: ExpressionTool
        inputs:
          vcfs: string[]
          vcfdir: Directory
        outputs:
          snvs_for_cleaning: File[]
        expression: |
            $({
                snvs_for_cleaning: (  filterFor("MUSE","snv_mnv", inputs.vcfs ).map(function(e) {
                    e = { "class":"File", "location":inputs.vcfdir.location+"/"+e }
                    return e;
                } )  )
            })

    clean_muse:
      doc: "Clean the MUSE VCFs."
      run: clean_vcf.cwl
      scatter: [vcf]
      in:
        vcf: gather_muse_snvs_for_cleaning/snvs_for_cleaning
      out: [clean_vcf]

    gather_clean_vcfs:
      doc: "combine cleaned VCFs (MUSE and non-MUSE)"
      in:
        clean_vcfs:
          source: clean/clean_vcf
        clean_muse_vcfs:
          source: clean_muse/clean_vcf
      out: [all_cleaned_vcfs]
      run:
        class: ExpressionTool
        inputs:
          clean_vcfs: File[]
          clean_muse_vcfs: File[]
        outputs:
          all_cleaned_vcfs: File[]
        expression: |
            $({
                all_cleaned_vcfs: inputs.clean_vcfs.concat(inputs.clean_muse_vcfs)
            })

    filter_for_indel:
      doc: "Filters the input list and selects the INDEL VCFs."
      in:
        in_vcf: gather_clean_vcfs/all_cleaned_vcfs
      out: [out_vcf]
      run:
        class: ExpressionTool
        inputs:
          in_vcf: File[]
        outputs:
          out_vcf: File[]
        expression: |
            $({ out_vcf: filterForIndels(inputs.in_vcf) })

    normalize:
      doc: "Normalize the INDEL VCFs."
      run: normalize.cwl
      scatter: normalize/vcf
      in:
        vcf:
          source: filter_for_indel/out_vcf
        ref: ref
      out: [normalized-vcf]

    extract_snv:
      doc: "Extract SNVs from normalized INDELs"
      run: extract_snv.cwl
      scatter: extract_snv/vcf
      in:
          vcf: normalize/normalized-vcf
      out: [ extracted_snvs ]

    # Remove "null" elements from the array.
    null_filter_extracted_snvs:
      in:
        extracted_snvs:
          source: extract_snv/extracted_snvs
        muse_files:
          source: clean_muse/clean_vcf
      run:
          class: ExpressionTool
          inputs:
              extracted_snvs:
                  type:
                      type: array
                      items: [ File, "null" ]
          outputs:
              cleaned_extracted_snvs: File[]
          expression: |
            $(
                { cleaned_extracted_snvs: inputs.extracted_snvs.filter(function(n){return n != null}) }
            )
      out: [cleaned_extracted_snvs]


    populate_output_record:
        in:
            extractedSnvs : null_filter_extracted_snvs/cleaned_extracted_snvs
            cleanedVcfs: gather_clean_vcfs/all_cleaned_vcfs
        out:
            [output_record]
        run:
            class: ExpressionTool
            inputs:
                extractedSnvs: File[]?
                cleanedVcfs: File[]
            outputs:
              output_record: "PreprocessedFilesType.yaml#PreprocessedFileset"
            expression: |
                    $(
                        {output_record: {
                            "cleanedVcfs": inputs.cleanedVcfs,
                            "extractedSnvs": inputs.extractedSnvs
                        }}
                    )
