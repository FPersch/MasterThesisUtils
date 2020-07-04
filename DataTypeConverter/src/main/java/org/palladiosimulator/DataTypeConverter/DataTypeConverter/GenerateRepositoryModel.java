package org.palladiosimulator.DataTypeConverter.DataTypeConverter;
import java.io.IOException;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;

import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.ResourceSet;
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl;
import org.palladiosimulator.pcm.repository.util.RepositoryResourceFactoryImpl;

public class GenerateRepositoryModel {
	private static final Logger logger = Logger.getLogger(GenerateRepositoryModel.class.getCanonicalName());
	private static final String modelName = "dataTypes";
	
	//arg[0] = path to msg-folder, arg[1] = path to ros-msg-folder
	public static void main(String[] args) {
		Resource.Factory.Registry reg = Resource.Factory.Registry.INSTANCE;
	    Map<String, Object> m = reg.getExtensionToFactoryMap();
	    m.put("repository", new RepositoryResourceFactoryImpl());
	    
		ResourceSet resourceSet = new ResourceSetImpl();
		Resource resource;
	    
	    CompositeDataTypeCreator creator = new CompositeDataTypeCreator(resourceSet);
	    
	    resource = resourceSet.createResource(URI.createURI(modelName + ".repository"));
	    resource.getContents().add((EObject) creator.create(args[0], args[1]));
	    
	 // save
	 	for (Resource res : resourceSet.getResources()) {
	 		try {
	 			res.save(null);
	 		} catch (IOException e) {
	 			logger.log(Level.SEVERE,"Could not store resource. ", e);
	 		}
	 	}
	 	logger.info("Models created successfully.");
	}
	 
}
