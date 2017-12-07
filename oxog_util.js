/**
 * Creates an array of files that will be used as input for OxoG.
 * @param in_data This is a TumourType object (see TumourType.yaml), representing a single tumour.
 * @param vcfsForOxoG This is an array of ALL available VCFs, from ALL tumours, as CWL File objects.
 * @return vcfsToUse Is an array of CWL File objects.
 */
function createArrayOfFilesForOxoG(in_data, vcfsForOxoG) {
	//TODO: Move this function to separate JS file.
	var vcfsToUse = []
	// Need to search through vcfsForOxoG (cleaned VCFs that have been zipped and index) and preprocess_vcfs/extractedSNVs to find VCFs
	// that match the names of those in in_data.inputs.associatedVCFs
	// associatedVcfs is the VCFs for the tumour represented by `in_data`.
	// Note: The data in associatedVcfs is just file names, the data objects in vcfsForOxoG are actual CWL File objects.
	var associatedVcfs = in_data.associatedVcfs
	// Loop through the VCFs for this given tumour...
	for (var i in associatedVcfs)
	{
		// We want SNVs, for OxoG
		if (associatedVcfs[i].indexOf(".snv") !== -1)
		{
			// Loop through ALL available VCFs. If there is a CWL File in vcfsForOxoG whose basename matches the associatedVcf,
			// add the CWL File to the output array (because we need to output CWL File objects, not just file names).
			for (var j in vcfsForOxoG)
			{
				if (vcfsForOxoG[j].basename.indexOf( associatedVcfs[i].replace(".vcf.gz","") ) !== -1 && /.*\.gz$/.test(vcfsForOxoG[j].basename))
				{
					vcfsToUse.push(vcfsForOxoG[j])
				}
			}
		}
		if (associatedVcfs[i].indexOf(".indel") !== -1)
		{
			for ( var j in vcfsForOxoG )
			{
				// If the associatedVcf is an INDEL, check if there were any SNVs extracted from it, and if so, add to the output array.
				if(vcfsForOxoG[j].basename.replace(".pass-filtered.cleaned.vcf.normalized.extracted-SNVs.vcf.gz","").indexOf( associatedVcfs[i].replace(".vcf.gz","") ) !== -1 && /.*\.gz$/.test(vcfsForOxoG[j].basename))
		 		{
					vcfsToUse.push(vcfsForOxoG[j])
				}
			}
		}
	}
	return vcfsToUse
}

/**
 * Flattens nested arrays into a single array.
 * @param array_of_arrays - an array that might contain subarrays as its elements.
 * @return All elements and subelements and sub-subelements (to any level of nesting) flattened into a single array with no nested elements.
 */
function flatten_nested_arrays(array_of_arrays)
{
	var flattened_array = []
	for (var i in array_of_arrays)
	{
		var item = array_of_arrays[i]
		if (item instanceof Array)
		{
            // console.log("found subarray")
			// recursively flatten subarrays.
			var flattened_sub_array = flatten_nested_arrays(item)
			for (var k in flattened_sub_array)
			{
                flattened_array.push(flattened_sub_array[k])
			}
		}
		else
		{
			flattened_array.push(item)
		}
	}
	return flattened_array
}
