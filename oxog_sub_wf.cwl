#!/usr/bin/env cwl-runner
cwlVersion: v1.0

doc: |
    This is a subworkflow - this is not meant to be run as a stand-alone workflow!

requirements:
    - class: SchemaDefRequirement
      types:
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
    oxogVCF:
        outputSource: sub_run_oxog/oxogVCF
        type: File[]
    oxogTBI:
        outputSource: sub_run_oxog/oxogTBI
        type: File[]
inputs:
    vcfsForOxoG:
        type: File[]
    inputFileDirectory:
        type: Directory
    in_data:
        type: "TumourType.yaml#TumourType"
    refDataDir:
        type: Directory

steps:
    sub_run_oxog:
        run: oxog.cwl
        in:
            inputFileDirectory: inputFileDirectory
            tumourID:
                source: [in_data]
                valueFrom: |
                    ${
                        return self.tumourId
                    }
            tumourBamFilename:
                source: [inputFileDirectory, in_data]
                valueFrom: |
                    ${
                        return { "class":"File", "location": self[0].location + "/" + self[1].bamFileName }
                    }
            refDataDir: refDataDir
            oxoQScore:
                source: [in_data]
                valueFrom: |
                    ${
                        return self.oxoQScore
                    }
            vcfNames:
                source: [in_data, vcfsForOxoG]
                valueFrom: |
                    ${
                        return createArrayOfFilesForOxoG(self[0], self[1])
                    }
        out: [oxogVCF, oxogTBI]
