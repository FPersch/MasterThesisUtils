package org.palladiosimulator.DataTypeConverter.DataTypeConverter

import org.palladiosimulator.pcm.repository.RepositoryFactory
import org.palladiosimulator.pcm.repository.CompositeDataType
import java.util.HashMap
import java.io.File
import java.util.Map
import java.io.IOException
import java.io.FileReader
import java.io.BufferedReader
import org.palladiosimulator.pcm.repository.PrimitiveTypeEnum
import org.palladiosimulator.pcm.repository.Repository
import java.util.regex.Pattern
import org.eclipse.emf.common.util.URI
import org.palladiosimulator.pcm.repository.DataType
import org.eclipse.emf.ecore.resource.ResourceSet
import org.palladiosimulator.pcm.repository.PrimitiveDataType

class CompositeDataTypeCreator {
	
	RepositoryFactory rf = RepositoryFactory.eINSTANCE
	Map<String, File> files = new HashMap
	Map<String, File> rosFiles = new HashMap
	Map<String, DataType> dataTypes = new HashMap
	var Repository repositoryRepository
	val ResourceSet rs 
	
	new(ResourceSet rs) {
		this.rs = rs
		createPrimitivesMapping()
	}
	
	def Repository create(String fileDir, String rosDir) {
		val directory = new File(fileDir)
		val rosDirectory = new File(rosDir)
		
		// filter project msgs
		for (File file : directory.listFiles) {
			val path = file.getPath
			files.put(file.getPath.substring(path.lastIndexOf("\\") + 1, path.lastIndexOf(".")), file)
		}
		
		// filter ros msgs
		for (File file : rosDirectory.listFiles) {
			val path = file.getPath
			if (path.contains("_msgs")) {
				var File msgs = new File(file + "\\msg")
				if (msgs.listFiles !== null) {
					for (File msg : msgs.listFiles) {
						var String msgPath = msg.path
						rosFiles.put(msgPath.substring(msgPath.lastIndexOf("\\") + 1, msgPath.lastIndexOf(".")), msg)
					} 
				}
			}
		}
		
		for (File file : directory.listFiles) {
			createCompositeDataType(file)
		}
		
		repositoryRepository = rf.createRepository => [
			entityName = "repoName"
			dataTypes.forEach[name, type|dataTypes__Repository += type]
		]
		return repositoryRepository
	}
	
	def void createCompositeDataType(File file) throws IOException {
		val input = new FileReader(file)
		val bufRead = new BufferedReader(input)
		var String myLine = null
		var int i = 0
		val fileName = file.getPath().substring(file.path.lastIndexOf("\\") + 1, file.path.lastIndexOf("."))
		
		if (!dataTypes.containsKey(fileName)) {
		
			var CompositeDataType cdt = rf.createCompositeDataType => [
				entityName = fileName
			]
			
			while ( (myLine = bufRead.readLine()) !== null) {
				val String[] line = myLine.split("\\s+")
				if (i > 2 && line.size > 1) {
					val dataType = line.get(0)
					val name = line.get(1)
					val subDir = dataType.contains("/")
					
					// case PalladioPrimitive
					if (PrimitiveTypeEnum.getByName(dataType.toUpperCase) !== null) {
						cdt.innerDeclaration_CompositeDataType += rf.createInnerDeclaration => [
							entityName = name
							datatype_InnerDeclaration = getPrimitiveTypeFromString(dataType.toUpperCase)							
						]
					
					// case already created data type
					} else if (dataTypes.containsKey(dataType)) {
						cdt.innerDeclaration_CompositeDataType += rf.createInnerDeclaration => [
							entityName = name
							datatype_InnerDeclaration = dataTypes.get(dataType)
						]
					// case collection data type
					} else if(dataType.contains("[]")) {
						createCollectionDataType(dataType)
						cdt.innerDeclaration_CompositeDataType += rf.createInnerDeclaration => [
							entityName = name
							datatype_InnerDeclaration = dataTypes.get(dataType.toFirstUpper)
						]
					// case unknown custom data type
					} else if (files.containsKey(dataType)) {
						createCompositeDataType(files.get(dataType))
						cdt.innerDeclaration_CompositeDataType += rf.createInnerDeclaration => [
							entityName = name
							datatype_InnerDeclaration = dataTypes.get(dataType)
						]
					// case ROS data type
					} else if (rosFiles.containsKey(dataType) || subDir) {
						if (subDir) {
							if (!dataTypes.containsKey(dataType.substring(dataType.lastIndexOf("/") + 1))) {
								createCompositeDataType(rosFiles.get(dataType.substring(dataType.lastIndexOf("/") + 1)))
							}
							cdt.innerDeclaration_CompositeDataType += rf.createInnerDeclaration => [
								entityName = name
								datatype_InnerDeclaration = dataTypes.get(dataType.substring(dataType.lastIndexOf("/") + 1))
							]
						} else {
							createCompositeDataType(rosFiles.get(dataType))
							
							cdt.innerDeclaration_CompositeDataType += rf.createInnerDeclaration => [
								entityName = name
								datatype_InnerDeclaration = dataTypes.get(dataType)
							]
						}
					// special case for time, still need to check if this should rather be int32 sec and int32 nsec instead of data
					} else if (dataType.contentEquals("time") || dataType.contentEquals("duration")) {
						val String int32 = "Int32"
						if (!dataTypes.containsKey(int32)) {
							createCompositeDataType(rosFiles.get(int32))
						}
						val intType = dataTypes.get(int32)
						val customPrimitive =  rf.createCompositeDataType => [
							entityName = dataType.toFirstUpper
							innerDeclaration_CompositeDataType += rf.createInnerDeclaration => [
								entityName = "sec"
								datatype_InnerDeclaration = intType
							]
							innerDeclaration_CompositeDataType += rf.createInnerDeclaration => [
								entityName = "nsec"
								datatype_InnerDeclaration = intType
							]
						]
						dataTypes.put(dataType.toFirstUpper, customPrimitive)
					// case like float32, int64
					} else {
						if (!dataType.contains("#") && !name.contains("#")) {
							if (!dataTypes.containsKey(dataType.toFirstUpper)) {
								createPrimitveVariant(dataType.toFirstUpper)
							}
							cdt.innerDeclaration_CompositeDataType += rf.createInnerDeclaration => [
								entityName = name
								datatype_InnerDeclaration = dataTypes.get(dataType.toFirstUpper)
							]
						}
					}
				}
				i++;
			}
			dataTypes.put(fileName, cdt)
		}
	}
	
	def createPrimitveVariant(String dataType) {
		var p = Pattern.compile("[^\\d]*([\\d]+)")
		var m = p.matcher(dataType)
		var countByte = 0
		if (m.find()) {
			var bits = Integer.parseInt(m.group(1))
            if (bits % 8 == 0) {
            	countByte = bits / 8
            }
        	val count = countByte;
			val customPrimitive =  rf.createCompositeDataType => [
				entityName = dataType
				for (var i = 0; i < count; i++) {
					val name = "byte" + i
					innerDeclaration_CompositeDataType += rf.createInnerDeclaration => [
						entityName = name
						datatype_InnerDeclaration = getPrimitiveTypeFromString("BYTE")
					]
				}
			]
			
			dataTypes.put(dataType, customPrimitive)
		}
	}	
	
	def createCollectionDataType(String dataType) {
		val String trimmedDataType = dataType.replace("[]", "")
		val collectionType = rf.createCollectionDataType => [
			entityName = dataType
			if (dataTypes.containsKey(trimmedDataType.toFirstUpper)) {
				innerType_CollectionDataType = dataTypes.get(trimmedDataType.toFirstUpper)
			} else if (PrimitiveTypeEnum.get(trimmedDataType.toFirstUpper) !== null){
				innerType_CollectionDataType = getPrimitiveTypeFromString(trimmedDataType.toFirstUpper)
			} else {
				if (files.containsKey(trimmedDataType.toFirstUpper)) {
					createCompositeDataType(files.get(trimmedDataType.toFirstUpper))
					innerType_CollectionDataType = dataTypes.get(trimmedDataType.toFirstUpper)
				} else if (rosFiles.containsKey(trimmedDataType.toFirstUpper)) {
					createCompositeDataType(rosFiles.get(trimmedDataType.toFirstUpper))
					innerType_CollectionDataType = dataTypes.get(trimmedDataType.toFirstUpper)
				}
			}
		]
		dataTypes.put(dataType, collectionType)
	}
	
	def createPrimitivesMapping() {
		val uriMap = rs.URIConverter.URIMap

		val String[][] mappings = #[
        	#["pathmap://PCM_MODELS/Palladio.resourcetype", "Palladio.resourcetype"],
        	#["pathmap://PCM_MODELS/PrimitiveTypes.repository", "PrimitiveTypes.repository"]
    	]

        for (String[] mapping : mappings) {
            if (!uriMap.containsKey(mapping.get(0))) {
                val cl = Thread.currentThread().getContextClassLoader();
 				val url = cl.getResource(mapping.get(1))?.toString();

                uriMap.put(URI.createURI(mapping.get(0)), URI.createURI(url));
            }
        }
	}
	
	def PrimitiveDataType getPrimitiveTypeFromString(String name) {
		var primitivesList = rs.getResource(URI.createURI("pathmap://PCM_MODELS/PrimitiveTypes.repository"), true).contents.get(0).eContents
		for (primitive : primitivesList) {
			var pdt = (primitive as PrimitiveDataType)
			if (pdt.type == PrimitiveTypeEnum.get(name)) {
				return pdt;
			}
		}
	}
}