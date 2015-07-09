# Must
* ~~Deferred variable assign (var = ?)~~
* ~~Make sure nextState is defined on exit~~
* ~~Generate state transition functions~~
* Particle creation functions
* Wildcard event match
* Event handler forwarding
* next_state variable
* get_waiting_event(particle_id)

# Useful
* Particle tag support (partcile Name[Tag1, Tag2, ...] : Parent { ... })
* Improve codegen error messages

# Maybe
* Aggregator implementation, enforce every aggregator is cleared before write

# Next state

Choosing next state is done via:

nextState = StateName

# Event handler forwarding

The old next state syntax is repurposed for forwarding

state ExtState @ _ => State, ...;

The next state is thus determined by the corresponding handler in State.

#Particle redesign

## Composition over inhertiance.

Syntax:

particle Particle1[Tag1, Tag2] << Particle2, Particle3 {
	...
}

'<<' is called 'mixin'

A mixin will pull in all its mixins as well. Every mixin should only be pulled in once, for example

B << A, D
C << A, E
F << B, C

Then F will pull in A, B, C, D, E exactly once each.

Variable with same name is considered duplication. State with same name is merged together, with their state transition table combined, and with the latter's entry action override the former's.

A mixin will also pull in all its tags as well, prevent pull in specific tags by:

particle Particle[Tag1, -Tag2] << ...

# Shared storage class (Abandoned)

Particles of the same exact type is allowed to share data. At particle creation time, 'sharing group' is defined, and particles with the same type and are in the same 'sharing group' will share some of their data.

If no sharing group is passed at creation time, then accessing shared data is a runtime error;

