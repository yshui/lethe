# High priority
- [ ] Texture
  - [ ] Texture packer
  - [ ] Syntax for getting texture coord from texture pack, at both runtime and compile-time
  - [ ] Generate texture at runtime and use them (Probably would be used for text)

# Must
- [x] Get rid of particle->\_\_id
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
- [x] Nil state to stop actor
- [x] Deleted state to delete particle
- [x] Vertice definition
- [ ] An interface to communicate (to D) what event an actor is waiting for
- [ ] Create particle with tags
- [x] Define particle with tags
- [ ] Event/EventMatch syntax tweaks
  - [ ] Event with zero parameters (Event() or Event should both be valid)
  - [ ] Take event parameter without match (Event(b) without using match like Event(b==1))
  - [ ] Ignore event parameter (Event(\_))
- [x] Random number syntax (Deprecated)
- [ ] Use proper exception rather than assert
- [x] Function support
- [ ] Migrate to use text template (mustache)

# Future

- [ ] Global static aggregator, loop over it is unrolled at compile time
- [ ] Static multiple dispatch by duplicate the code at compile time
- [ ] Array support, see Details

# Useful
* Improve codegen error messages

# Maybe not
* Entry action of state: Is this really useful?, when should it run (before/after event fence)?

# Details

## Array

struct array {
	const struct array *base;
	struct array *new;
	bool cleared;
}

On event fence, new and base in \_\_next are merge to form a new base, if cleared == true, new base is empty

On <<, stuffs are put into new
On ~, new is cleared and cleared is set to true

## Random syntax (Deprecated)

```
$(range), e.g. $(1..20) for random interger >= 1 and < 20. $(0.0..1.0) for random real number
```

## Vertice definition

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

## Unified matching syntax

### In condition

Condition => EventName "(" Matcher ("," Matcher)\* ")"

Matcher => ParticleMatcher / MatchExpression

ParticleMatcher => ParticleName "(" ("\_" / Variable) ")"

MatchExpression => Variable ("~"/"=="/"<="/">="/"<"/">") Expression

### In if statement

IfLet => "if" "let" ParticleMatcher = Variable

If => "if" BooleanExpresion

## Event handler forwarding

The old next state syntax is repurposed for forwarding

state ExtState @ _ => State, ...;

The next state is thus determined by the corresponding handler in State.

## Particle redesign

### Composition over inhertiance.

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

## Shared storage class (Abandoned)

Particles of the same exact type is allowed to share data. At particle creation time, 'sharing group' is defined, and particles with the same type and are in the same 'sharing group' will share some of their data.

If no sharing group is passed at creation time, then accessing shared data is a runtime error;


