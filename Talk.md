# Haskelling Bitcoin for Great Good

## Motivation

Throughout history, the way software has been written is a reflection of the environment it had to operate in. The tools
and processes we choose to develop and use were designed to make certain tradeoffs. And while certain tools and methods
may be pareto optimal against others, the vast majority of them involve making tradeoffs by sacrificing benefits that
matter less to our problem domain, in exchange for getting others that we value more strongly.

For most of recent history, most if not all of us have been approaching softwre development has been through the lens of
the internet and the web. Web software was an incredible boon to the startup crowd. It meant that we could stop doing
expensive waterfall releases in favor of punting things out the door as soon as they began to look like they even 
slightly worked. The reason that we could do this is because if something broke or we needed to ship an improvement, we
just push new code, bounce the servers and we're up an running on a new version. Bugs were cheap.

Then came Bitcoin.

Undoubtedly many of you have heard of Bitcoin or the other insanity that happened last year with the ICO madness. But
what is it? If we cut through all the buzzwords of "blockchain", "decentralization", and "peer-to-peer networks". Bitcoin
managed to create a piece of distributed software whereby every node in the system can agree about the current state
without being able to trust the other participants. This has all sorts of benefits from software resilience, to more
political benefits like minimizing corruption risk. The downside is that it presents us with a new era of software
design where certain types of updates are extremely difficult if not impossible to execute. To make matters worse, we 
have endowed these software systems with several hundred billion dollars worth of value.

With billions of dollars of value on the line and no reasonable way to deploy patches if we get things wrong, the web
development philosophy and toolset simply cease to be viable. In some ways, this kind of software more closely resembles
flight software for aerospace projects than it does the web software that a lot of us have been writing for the last 2 
decades.

So why is that important, especially to a functional programming conference? Well the tools we choose to build software
where Failure is not an Option™ look a lot different than the ones we choose when mistakes can be quickly remedied.

Correctness is more important than speed of development in this industry. So what do we do here? Use tools that give us 
as many statically enforceable guarantees as possible. Pure functional programming with strong static typing and 
denotational semantics gives us a powerful way to reason about the correctness of our software, at the cost of having 
new developers being a little less productive than they would be if they had used a scripting language like javascript. 
In the web days this may have been the wrong tradeoff. However, in the trustware industry, I contend that those days are 
over.

## Proof of Concept

With that in mind, the meat of this talk is a more practical introduction to building consensus software in Haskell
specifically. Why Haskell, because it's the language with the most statically enforced properties that I actually know.
If I was proficient in Idris, and it had a more mature ecosystem, perhaps I may have chosen that for this talk.

When I was learning Haskell, it didn't take long for me to become fascinated with the level of rigor that it enforces
on your understanding of your problem domain. But for the longest time I had trouble imagining how to solve more
substantial problems using it because it seemed to take away all of the tools I was used to using to get any important
work done, like state changes, accepting user input and displaying output to the user. Now of course, as we all know, it
is a complete myth that you can't build substantial software in Haskell and my goal for this talk is to demonstrate not 
only that we can build a toy cryptocurrency with it, but convince you that this should be the default choice* in this
space.

The remainder of this talk will assume that you know the basic affordances of cryptographic primitives such as hashing
and public key cryptography, as well as a Fire Lubline™ proficiency with Haskell.

When I was originally proposing this talk I had the naive hope that we could touch at least a little bit on everything
that goes into a minimum viable cryptocurrency. But I was terribly wrong, so there are certain things we will have to
skip over the details of, but I'll do my best to mention where I'm skipping over so at least you know there are dark
corners to be investigated here.

## Transaction Structure

So the type of ledger we are going to be building is what is referred to as a UTXO based ledger. This differs from an
account ledger in some key ways that make it far easier to make bad states unrepresentable. Remember that we are willing
to absorb complexity if it maximizes our ability to prevent ourselves deploying bad code to thousands of computers we don't
have any administrative control over. So let's exploit the structure of our data and program such that it makes bad states unrepresentable.

A UTXO based ledger is one that references previous transactions to prove that you possess funds to be able to spend them
and an account based ledger is one that references current balances to prove that you have the funds to spend them. One
of the nice things about UTXO based ledgers is that they are easier to reason about when it comes to knowing whether or
not a user has already spent funds. This effect is compounded when operating in an immutable append-only data structure
that we will talk more in depth about later.

UTXO stands for Unspent Transaction (TX) Output. If we examine a transaction every transaction has outputs, or destinations
and inputs or sources. The nature of these transactions is that the outputs of transactions that transfer funds to you
become the inputs of transactions that you use to transfer funds to someone else.

Before diving into the implementation of a UTXO based ledger we need to understand a couple of the constraints that this
model imposes. For one, in order to guarantee that money isn't created or destroyed we have to ensure that when we reference
a transaction we must spend all of the funds that it affords us. However, a currency where you can only spend discrete
units governed by the arbitrary division of transactions you've received in the past, wouldn't be all that useful. So
we need to be able to use more than one input in a transaction, and we need to be able to cut that value up into more than
one output. So we know enough now about the structure of a transaction that we can model it as a datatype.

### Code

So what we need is a UTXO structure that has a unique ID and a specification of who can spend it. So we'll assume that
every transaction will have an ID and a list of outputs, so we know that we at least need those as parts of the UTXO
structure. We also know that we need a destination, and certainly a value of how much that UTXO is worth.

So now that we have a format for representing our UTXO, we need to specify what a transaction is. Well as we talked about
before, we need to take a set of UTXO's as inputs and produce a set of UTXO's as outputs. Easy enough, however, we need
one more piece of information: we need to provide the piece of information that actually authorizes us to spend those funds
which in this case is a public key that corresponds with the hash specified in the destination, and a signature that proves
we have the private key that these funds were encumbered to.

## Keys and Signing

So in order to use my private key to spend funds I need to be able to create a transaction and sign it. But what exactly
am I signing? Well, the first thing I need to include in the signature is the inputs. Those, after all, are what I'm spending
and therefore the rest of the network will require that I actually sign that input. The other piece I want to sign is
the set of outputs. What a cryptographic signature does is "bake" or "finalize" a piece of data such that it can no longer
be changed without breaking the signature. So I want the destination of the money to be finalized before signing.
So to do this we need to make sure that our transaction that we are signing includes all that information. So I have
included a structure here known as an unsigned transaction you'll notice is lacking all the public keys and signatures.
So what we'll do is serialize that transaction, hash it and then sign the hash, after which we will include it in our
transaction structure.

The library that will be doing all of the heavy lifting here is CryptoNite. This is an excellent library that while not
suitable for all purposes, will do just fine for the vast majority of cryptography needs you have. 

## Peer to Peer Networking

So we have signed this transaction. Now what do we do with it? Well we have to tell people about it otherwise no one
will ever know that it happened. And since Bitcoin is a decentralized system there's no server to tell. So we need
to tell anyone in the Bitcoin network that we know about that this happened. For that we need a peer to peer network.
What we need to do is every time we want to send a transaction, we need to tell all our peers about this transaction,
and consequently whenever we hear about a transaction we haven't seen before, we need to tell all our peers about that
as well.

To tell all our peers about stuff we need a way to take the structures we've made and figure out how to serialize them
over the network such that other nodes can decode them and get the same structure on the other side. We will need to 

## Consensus Rules

Now the heart of bitcoin is its consensus rules. This is what governs how the network actually works and allows you to
spend or not spend. In order for your transaction to be valid it needs to not violate certain invariants in the system.
The most obvious one is that the signatures need to be valid or you'd be able to spend someone else's coins

## TODO

## Ledger Structure

So now that we have a transaction structure we actually have all we need to represent state change with respect to the
transfer of ownership of some currency. Great! Now the trouble with this is that we have no way to make sure that I don't
take two different transactions that reference the same input and send each of them to two different people. This is known
as the double spend problem. In order to deal with this, we have to assemble all of the transactions into a single ledger.

The ledger's purpose is to ensure that all transactions are put into a canonical order. That is the order that they go
into the ledger is agreed upon by all participants in the system. However, since we are operating in an environment where
we can't necessarily trust the other participants in the system we need a mechanism for confirming the validity of this
ledger. So what's our favorite way to make sure no one has screwed with our data? Hashing. So in order to be able to
preserve the order of our transactions in a tamper evident way we need each entry in the ledger to identify the ledger
upon which it is buiding. Now we could have every transaction reference the previous transaction in the ledger but this
is prone to getting out of sync as inevitably two people decide to build on the same ledger. To reduce this noise, we
will group our transactions into blocks. And each block will contain a reference to the previous block's hash.

This is what is known as a blockchain. If we view our ledger as a Directed-Acyclic-Graph of transactions, and we collapse
groups of these transactions into discrete synchronous chunks, then what we get is a chain of ledger units that contain
transactions.

## Proof of Work

## TODO