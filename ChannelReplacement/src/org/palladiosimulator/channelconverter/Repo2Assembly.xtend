package org.palladiosimulator.channelconverter

import org.palladiosimulator.pcm.repository.RepositoryFactory
import org.palladiosimulator.pcm.core.composition.CompositionFactory
import org.palladiosimulator.pcm.repository.Repository
import org.palladiosimulator.pcm.system.System
import org.palladiosimulator.pcm.repository.BasicComponent
import org.palladiosimulator.indirections.repository.DataSinkRole
import org.palladiosimulator.indirections.repository.DataSourceRole
import org.palladiosimulator.pcm.repository.OperationProvidedRole
import org.palladiosimulator.indirections.system.DataChannel
import java.util.Map
import java.util.HashMap
import org.palladiosimulator.pcm.repository.EventGroup
import org.palladiosimulator.indirections.datatypes.ConsumeFromChannelPolicy
import org.palladiosimulator.indirections.datatypes.EmitToChannelPolicy
import org.palladiosimulator.indirections.datatypes.NumberOfElements
import org.palladiosimulator.indirections.datatypes.Scheduling

class Repo2Assembly {
	RepositoryFactory rf = RepositoryFactory.eINSTANCE
	CompositionFactory cf = CompositionFactory.eINSTANCE
	org.palladiosimulator.indirections.composition.CompositionFactory icf = org.palladiosimulator.indirections.composition.CompositionFactory.eINSTANCE
	org.palladiosimulator.indirections.system.SystemFactory isf = org.palladiosimulator.indirections.system.SystemFactory.eINSTANCE
	
	val Repository repository
	val System system
	val Map<EventGroup, DataChannel> dataChannels
	
	new(Repository repository, System system) {
		this.repository = repository
		this.system = system
		this.dataChannels = new HashMap()
	}
	
	def transform() {
		createDataChannel
		createAssemblyEntriesForBasicComponent
		println("Assembly successfully created.")
	}
	
	def createDataChannel() {
		for (group : repository.interfaces__Repository) {
			if (group instanceof EventGroup) {
				val channel = isf.createDataChannel => [
					capacity = -1
					consumeFromChannelPolicy = ConsumeFromChannelPolicy.REMOVE
					emitToChannelPolicy = EmitToChannelPolicy.DISCARD_OLDEST_IF_FULL
					entityName = "DataChannel_" + group.entityName
					numberOfElementsToEmit = NumberOfElements.ANY_NUMBER
					scheduling = Scheduling.FIRST_IN_FIRST_OUT
					eventGroup__EventChannel = group
					sinkEventGroup = group
					sourceEventGroup = group
				]
				dataChannels.put(group, channel)
				system.eventChannel__ComposedStructure += channel
			}
		}
	}
	
	def createAssemblyEntriesForBasicComponent() {
		for (component : repository.components__Repository) {
			if (component instanceof BasicComponent) {
				// create AssemblyContext
				val context = cf.createAssemblyContext => [
					entityName = "Assembly_" + component.entityName
					encapsulatedComponent__AssemblyContext = component
				]
				system.assemblyContexts__ComposedStructure += context
				for (required : component.requiredRoles_InterfaceRequiringEntity) {
					// create DataSourceRole
					if (required instanceof DataSourceRole) {
						val channel = dataChannels.get(required.eventGroup)
						val source = icf.createDataChannelSourceConnector => [
							entityName = "SourceConnector_" + required.entityName
							assemblyContext = context
							dataSourceRole = required
							dataChannel = channel
						]
						channel.dataChannelSourceConnector += source
						system.connectors__ComposedStructure += source
					}
				}
				for (provided : component.providedRoles_InterfaceProvidingEntity) {
					// create DataSinkRole
					if (provided instanceof DataSinkRole) {
						val channel = dataChannels.get(provided.eventGroup)
						val sink = icf.createDataChannelSinkConnector => [
							entityName = "SinkConnector_" + provided.entityName
							assemblyContext = context
							dataSinkRole = provided
							dataChannel = channel
						]
						channel.dataChannelSinkConnector += sink
						system.connectors__ComposedStructure += sink
						
					} else if (provided instanceof OperationProvidedRole) {
						// create OperationProvidedRole
						val operationProvided = rf.createOperationProvidedRole => [
							entityName = "Interface_" + provided.providedInterface__OperationProvidedRole.entityName + "_ProvidedRole"
							providedInterface__OperationProvidedRole = provided.providedInterface__OperationProvidedRole
						]
						// create ProvidedDelegationConnector
						system.connectors__ComposedStructure += cf.createProvidedDelegationConnector => [
							assemblyContext_ProvidedDelegationConnector = context
							entityName = "ProvidedDelegationConnector_" + provided.entityName
							innerProvidedRole_ProvidedDelegationConnector = provided
							outerProvidedRole_ProvidedDelegationConnector = operationProvided
						]
						system.providedRoles_InterfaceProvidingEntity += operationProvided
					}
				}
			}
		}
	}
}