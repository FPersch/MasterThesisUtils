package org.palladiosimulator.channelconverter

import org.palladiosimulator.pcm.repository.Repository
import org.palladiosimulator.pcm.system.System
import org.palladiosimulator.pcm.allocation.Allocation
import org.palladiosimulator.indirections.system.DataChannel
import org.palladiosimulator.pcm.repository.RepositoryFactory
import org.palladiosimulator.pcm.allocation.AllocationFactory
import org.palladiosimulator.indirections.composition.DataChannelSinkConnector
import org.palladiosimulator.indirections.datatypes.ConsumeFromChannelPolicy
import org.palladiosimulator.pcm.repository.BasicComponent
import org.palladiosimulator.pcm.core.composition.CompositionFactory
import org.palladiosimulator.pcm.core.composition.AssemblyContext
import org.palladiosimulator.indirections.repository.DataSinkRole
import org.palladiosimulator.pcm.seff.SeffFactory
import org.palladiosimulator.indirections.actions.ActionsFactory
import org.palladiosimulator.pcm.seff.AbstractAction
import de.uka.ipd.sdq.stoex.StoexFactory
import org.palladiosimulator.indirections.repository.DataSourceRole
import org.palladiosimulator.indirections.composition.DataChannelSourceConnector
import org.palladiosimulator.pcm.resourceenvironment.ResourceContainer
import java.util.HashMap
import java.util.Map
import org.palladiosimulator.indirections.datatypes.NumberOfElements
import java.util.ArrayList
import java.util.List
import org.palladiosimulator.pcm.core.composition.EventChannel

class DataChannelTransformator {
	
	RepositoryFactory rf = RepositoryFactory.eINSTANCE
	org.palladiosimulator.indirections.repository.RepositoryFactory irf = org.palladiosimulator.indirections.repository.RepositoryFactory.eINSTANCE
	org.palladiosimulator.indirections.system.SystemFactory isf = org.palladiosimulator.indirections.system.SystemFactory.eINSTANCE
	AllocationFactory af = AllocationFactory.eINSTANCE
	CompositionFactory cf = CompositionFactory.eINSTANCE
	org.palladiosimulator.indirections.composition.CompositionFactory icf = org.palladiosimulator.indirections.composition.CompositionFactory.eINSTANCE
	SeffFactory rdsf = SeffFactory.eINSTANCE 
	ActionsFactory irdsf = ActionsFactory.eINSTANCE
	StoexFactory stoexf = StoexFactory.eINSTANCE
	val Repository repository
	val System system
	val Allocation allocation
	val Map<String, DataSourceRole> sourceRoles
	
	new(Repository repository, System system, Allocation allocation) {
		this.repository = repository
		this.system = system
		this.allocation = allocation
		this.sourceRoles = new HashMap()
	}
	
	def transform() {
		var List<EventChannel> channels = new ArrayList()
		channels.addAll(system.eventChannel__ComposedStructure)
		for (channel : channels) {
			if (channel instanceof DataChannel) {
				var data = channel as DataChannel
				if (data.dataChannelSinkConnector.size > 1) {
					val container = getResourceContainer(data)
					var pub = createPublisher(data)
					val context = createPublisherAssemblyContext(pub, container)
					createNewDataChannel(data, context, pub, container)
					var sink = createPublisherSinkConnector(data, context, pub)
					data.dataChannelSinkConnector.clear
					data.dataChannelSinkConnector += sink
					data.consumeFromChannelPolicy = ConsumeFromChannelPolicy.PUSHING
					data.numberOfElementsToEmit = NumberOfElements.EXACTLY_ONE
				}
			}
		}
		println("Transformation complete.")
	}
	
	def fixEventGroup() {
		for (channel : system.eventChannel__ComposedStructure) {
			var dc = channel as DataChannel
			if (dc.eventGroup__EventChannel === null) {
				dc.eventGroup__EventChannel = dc.sinkEventGroup
			}
		}
	}
	
	def ResourceContainer getResourceContainer(DataChannel channel) {
		for (alloc : allocation.allocationContexts_Allocation) {
			if (alloc.eventChannel__AllocationContext !== null) {
				if (alloc.eventChannel__AllocationContext.id.contentEquals(channel.id)) {
					return alloc.resourceContainer_AllocationContext
				}
			}
		}
	}
	
	def createNewDataChannel(DataChannel oldChannel, AssemblyContext context, BasicComponent publisher, ResourceContainer container) {
		var List<DataChannelSinkConnector> subscriber = new ArrayList()
		subscriber.addAll(oldChannel.dataChannelSinkConnector)
		for (sink : subscriber) {
			val dataChannel = isf.createDataChannel => [
				entityName = "Channel_" + sink.entityName
				capacity = oldChannel.capacity
				if (sink.dataSinkRole.pushing) {
					consumeFromChannelPolicy = ConsumeFromChannelPolicy.PUSHING
					numberOfElementsToEmit = NumberOfElements.EXACTLY_ONE
				} else {
					consumeFromChannelPolicy = ConsumeFromChannelPolicy.REMOVE
					numberOfElementsToEmit = oldChannel.numberOfElementsToEmit
				}
				emitToChannelPolicy = oldChannel.emitToChannelPolicy
				scheduling = oldChannel.scheduling
				dataChannelSinkConnector += sink
				sourceEventGroup = oldChannel.sinkEventGroup
				sinkEventGroup = oldChannel.sourceEventGroup
				eventGroup__EventChannel = oldChannel.eventGroup__EventChannel
			]
			dataChannel.dataChannelSourceConnector += createPublisherSourceConnector(dataChannel, context, publisher, sink)
			system.eventChannel__ComposedStructure += dataChannel
			
			// register in allocation
			allocation.allocationContexts_Allocation += af.createAllocationContext => [
				entityName = "Allocation_" + dataChannel.entityName
				eventChannel__AllocationContext = dataChannel
				resourceContainer_AllocationContext = container
			]
		}
	}
	
	def DataChannelSinkConnector createPublisherSinkConnector(DataChannel oldChannel, AssemblyContext context, BasicComponent publisher) {
		var sinkConnector = icf.createDataChannelSinkConnector => [
			entityName = "SinkConnector_" + publisher.entityName
			assemblyContext = context
			dataChannel = oldChannel
			dataSinkRole = publisher.providedRoles_InterfaceProvidingEntity.head as DataSinkRole
		]
		system.connectors__ComposedStructure += sinkConnector
		return sinkConnector
	}
	
	def DataChannelSourceConnector createPublisherSourceConnector(DataChannel newChannel, AssemblyContext context, BasicComponent publisher, DataChannelSinkConnector sink) {
		var sourceConnector = icf.createDataChannelSourceConnector => [
			entityName = "SourceConnectorTo_" + sink.assemblyContext.entityName
			assemblyContext = context
			dataChannel = newChannel
			dataSourceRole = sourceRoles.get(sink.id)
		]
		system.connectors__ComposedStructure += sourceConnector
		return sourceConnector
	}
	
	def AssemblyContext createPublisherAssemblyContext(BasicComponent publisher, ResourceContainer container) {
		val context = cf.createAssemblyContext => [
			entityName = "Assembly_" + publisher.entityName
			encapsulatedComponent__AssemblyContext = publisher
		]
		system.assemblyContexts__ComposedStructure += context
		
		allocation.allocationContexts_Allocation += af.createAllocationContext => [
			entityName = "Allocation_" + context.entityName
			assemblyContext_AllocationContext = context
			resourceContainer_AllocationContext = container
		]
		return context
	}
	
	def BasicComponent createPublisher(DataChannel oldChannel) {
		val name = "Distributor_" + oldChannel.entityName
		val signature = oldChannel.sinkEventGroup.eventTypes__EventGroup.head
		var pub = rf.createBasicComponent => [
			entityName = name
			providedRoles_InterfaceProvidingEntity += irf.createDataSinkRole => [
				entityName = "incoming" + name
				eventGroup = oldChannel.sinkEventGroup
				pushesTo = signature
			]
			serviceEffectSpecifications__BasicComponent += rdsf.createResourceDemandingSEFF => [
				describedService__SEFF = signature
				
				var start = rdsf.createStartAction => [
					entityName = "start" + name
				]
				
				steps_Behaviour += start
				
				var AbstractAction predecessor = start
				for (DataChannelSinkConnector sink : oldChannel.dataChannelSinkConnector) {
					
					val sourceRole = irf.createDataSourceRole => [
						entityName = "outgoingTo" + sink.assemblyContext.entityName
						eventGroup = oldChannel.sourceEventGroup
					]
					
					var emit = irdsf.createEmitDataAction => [
						entityName = "emit_" + sink.entityName
						eventType = oldChannel.sinkEventGroup.eventTypes__EventGroup.head
						dataSourceRole = sourceRole
						variableReference = stoexf.createVariableReference => [
							referenceName = oldChannel.sinkEventGroup.eventTypes__EventGroup.head.parameter__EventType.parameterName
						]
					]
					sourceRoles.put(sink.id, sourceRole)
					emit.predecessor_AbstractAction = predecessor
					predecessor.successor_AbstractAction = emit
					steps_Behaviour += emit
					predecessor = emit
				}
				var stop = rdsf.createStopAction => [
					entityName = "stop" + name
				]
				stop.predecessor_AbstractAction = predecessor
				predecessor.successor_AbstractAction = stop
				steps_Behaviour += stop
			]
			requiredRoles_InterfaceRequiringEntity.addAll(sourceRoles.values)
		]
		repository.components__Repository += pub
		return pub
	}
}
