# Must
- [x] Deferred variable assign (var = ?)
- [x] Make sure nextState is defined on exit
- [x] Generate state transition functions
- [x] nextState = StateName
- [x] Unified matching syntax
- [x] Particle creation functions
- [x] Create events with particle member
- [ ] Wildcard event match
- [ ] Event handler forwarding
- [x] Event fence, events between fences are sent at the same time
- [ ] Aggregators
  - [x] Event Aggregators
  - [x] Render Aggregators
  - [x] Collision aggregator (register collision box)
- [ ] Nil state to stop actor
- [ ] A way to delete particle
- [x] Vertice definition
- [ ] An interface to communicate (to D) what event an actor is waiting for
- [ ] Create particle with tags
- [x] Define particle with tags
- [ ] Event/EventMatch syntax tweaks
  - [ ] Event with zero parameters (Event() or Event should both be valid)
  - [ ] Take event parameter without match (Event(b) without using match like Event(b==1))
  - [ ] Ignore event parameter (Event(\_))
- [ ] Random number syntax

# Useful
* Improve codegen error messages

# Maybe not
* Entry action of state: Is this really useful?, when should it run (before/after event fence)?

# Random syntax

```
$(range), e.g. $(1..20) for random interger >= 1 and < 20. $(0.0..1.0) for random real number
```

# Vertice definition

//Verbose, consistent with particle definition
vertex VertexName {
	type name;
}

or

//Simpler, consistent with event definition
//But name: type is not used in particle defintion
vertex VertexName(name: type, ...);

or

//This
vertex VertexName(type name, ...);

# Unified matching syntax

## In condition

Condition => EventName "(" Matcher ("," Matcher)\* ")"

Matcher => ParticleMatcher / MatchExpression

ParticleMatcher => ParticleName "(" ("\_" / Variable) ")"

MatchExpression => Variable ("~"/"=="/"<="/">="/"<"/">") Expression

## In if statement

IfLet => "if" "let" ParticleMatcher = Variable

If => "if" BooleanExpresion

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


