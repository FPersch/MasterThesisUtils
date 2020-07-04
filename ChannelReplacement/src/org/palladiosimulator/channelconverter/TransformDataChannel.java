package org.palladiosimulator.channelconverter;

import java.io.File;
import java.io.IOException;

import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.ResourceSet;
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl;
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl;
import org.palladiosimulator.pcm.allocation.Allocation;
import org.palladiosimulator.pcm.allocation.AllocationPackage;
import org.palladiosimulator.pcm.parameter.ParameterPackage;
import org.palladiosimulator.pcm.repository.Repository;
import org.palladiosimulator.pcm.repository.RepositoryPackage;
import org.palladiosimulator.pcm.resourceenvironment.ResourceenvironmentPackage;
import org.palladiosimulator.pcm.resourcetype.ResourcetypePackage;
import org.palladiosimulator.pcm.seff.SeffPackage;
import org.palladiosimulator.pcm.usagemodel.UsagemodelPackage;
import org.palladiosimulator.pcm.system.System;
import org.palladiosimulator.pcm.system.SystemPackage;

public class TransformDataChannel {
	
	public static void main(String[] args) {
		ResourceSet resourceSet = new ResourceSetImpl();
		resourceSet.getResourceFactoryRegistry().getExtensionToFactoryMap().put(Resource.Factory.Registry.DEFAULT_EXTENSION, new XMIResourceFactoryImpl());
		Repository repository;
		System system;
		Allocation allocation;
		
		File repo = new File (args[0] + "newRepository.repository");
		File sys = new File (args[0] + "newAssembly.system");
		File alloc = new File (args[0] + "newAllocation.allocation");
		
	    registerPackages(resourceSet);
		
		
		repository = (Repository) resourceSet.getResource(URI.createFileURI(repo.getAbsolutePath()), true).getContents().iterator().next();
		system = (System) resourceSet.getResource(URI.createFileURI(sys.getAbsolutePath()), true).getContents().iterator().next();
		allocation = (Allocation) resourceSet.getResource(URI.createFileURI(alloc.getAbsolutePath()), true).getContents().iterator().next();
		
		DataChannelTransformator dct = new DataChannelTransformator(repository, system, allocation); 
		dct.transform();
		
		for (Resource res : resourceSet.getResources()) {
	 		try {
	 			res.save(null);
	 		} catch (IOException e) {
	 		}
	 	}
	}
	
	private static void registerPackages(final ResourceSet resourceSet) {

        resourceSet.getPackageRegistry().put(AllocationPackage.eNS_URI, AllocationPackage.eINSTANCE);
        resourceSet.getPackageRegistry().put(ParameterPackage.eNS_URI, ParameterPackage.eINSTANCE);
        resourceSet.getPackageRegistry().put(ResourceenvironmentPackage.eNS_URI, ResourceenvironmentPackage.eINSTANCE);
        resourceSet.getPackageRegistry().put(ResourcetypePackage.eNS_URI, ResourcetypePackage.eINSTANCE);
        resourceSet.getPackageRegistry().put(RepositoryPackage.eNS_URI, RepositoryPackage.eINSTANCE);
        resourceSet.getPackageRegistry().put(SeffPackage.eNS_URI, SeffPackage.eINSTANCE);
        resourceSet.getPackageRegistry().put(SystemPackage.eNS_URI, SystemPackage.eINSTANCE);
        resourceSet.getPackageRegistry().put(UsagemodelPackage.eNS_URI, UsagemodelPackage.eINSTANCE);
        resourceSet.getPackageRegistry().put(org.palladiosimulator.indirections.repository.RepositoryPackage.eNS_URI, org.palladiosimulator.indirections.repository.RepositoryPackage.eINSTANCE);
        resourceSet.getPackageRegistry().put(org.palladiosimulator.indirections.system.SystemPackage.eNS_URI, org.palladiosimulator.indirections.system.SystemPackage.eINSTANCE);
    }
}
