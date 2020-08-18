# GlobalId

## Goal

Build a system to assign unique numbers to each resource that we manage.

## Constraints

* IDs must be unique. Each ID can only be given out at most once.
* The IDs are 64 bits long.
* The service is composed of a set of nodes, each running one process serving IDs.
* A caller will connect to one of the nodes and ask it for a globally unique ID.
* There are a fixed number of nodes in the system, up to 1024.
* Each node has a numeric ID, where `0 <= id <= 1023`.
* Each node knows its ID at startup and that ID never changes for the node.
* No node will receive more than 100,000 requests per second.

## Assumptions

* The IDs can be up to 64 bits, but it is acceptable if some IDs are smaller. I am assuming that the 64-bit requirement deals with storage constraints or numeric processing. We can satisfy those constraints as long as we stay under the `2^64 - 1` limit.
* The 64-bit number is unsigned.
* Each node has one process serving IDs, but it can have helper processes. Processes in Erlang and Elixir are cheap. I'm assuming that spawning up a helper process is okay, as long as the system can still serve 100,000 requests per second.
* Our system will not be in use in the 22nd century. It will take 266 more years for our Unix timestamp to increase by another digit, so we should be fine for a few more generations. After that point, the global IDs exceed the 64-bit size constraint.
* It's okay for the `GlobalId.timestamp/0` function to return the Unix timestamp in seconds, rather than milliseconds. It's a public function, so changing the interface is not ideal. I'm assuming that the only code calling this function is contained within the `GlobalId` module, however. If this assumption is incorrect, `timestamp/0` could just return the Unix timestamp in milliseconds, and I could truncate the last three digits where I use the timestamp. My solution requires the timestamp to have 10 digits or fewer. That is so the entire global ID stays under 2^64.
* `GlobalId.timestamp/0` is monotonically increasing. My implementation uses `DateTime.utc_now/0` for ease of illustration and testing. However, `GlobalId.timestamp/0` internally calls `System.os_time/0`, which calls Erlang's `:os.system_time/0`. `:os.system_time/0` is [_not_ monotonically increasing](http://erlang.org/doc/man/os.html#system_time-0). A more robust implementation of `GlobalId.timestamp/0` would deal with [time warps](http://erlang.org/doc/apps/erts/time_correction.html#time-warp).
* After a node restarts, the `GlobalId.timestamp/0` function will operate as if the node had never shut down. In other words, the `GlobalId.timestamp/0` function's return values _after_ a node restart are always greater than the values _before_ the restart.
* `GlobalId.node_id/0` can just return a hard-coded integer for demonstration purposes. The real implementation would return a real node ID.
* Node crashes will take one or more seconds to recover from. If a node recovers more quickly than that, my solution could generate some duplicate IDs.
* It is acceptable for us to wait 1 second to restart a process that crashed. See below for more discussion about this.

## The general approach
I take the number of seconds since the Unix epoch, prefix it with the node ID, and suffix it with a number between 0 and 999,999. I use a helper process to keep track of the number suffix, which changes with each request.

The solution requires no coordination between nodes, and no persistent storage. It is resilient to node restarts. It can also handle over 100,000 requests/second. I'm giving up some robustness to gain some code simplicity. Further discussions about requirements may lead me to a different design choice.

## Why the solution works
The solution always returns a 16- to 20-digit positive integer in this form:

```
aaaabbbbbbbbbbcccccc
```

Each letter represents a grouping of digits. It doesn't imply that all digits in the group are identical.

* The first zero to four digits (`a`) represent the node ID.
* The next 10 digits (`b`) contain the Unix timestamp.
* The last six digits (`c`) contain a number between 0 and 999,999.

Let's take a look at each part of the global ID.

### Node ID

The first zero to four digits represent the node ID. If the node ID is 0, we won't add any numeric prefix to our global ID. If 1 <= node ID < 10, there will be a single-digit prefix. If 10 <= node ID < 100, there will be a double-digit prefix. If 100 <= node ID < 1000, there will be a triple-digit prefix. If 1000 <= node ID < 1024, the node ID prefix will be four digits.

This acts like a namespace to our global ID. As long as the remaining digits are unique for a particular node, the entire global ID will be unique across nodes.

### Unix timestamp

The 10 `b` digits above represent the Unix timestamp in seconds. As long as a pair of timestamps and number suffix is unique, the global ID will be unique.

### Quasi-random number
I use a process to maintain an integer in some state. This integer increases by one each time we ask for it. After the integer reaches 999,999, we reset the integer to 0. This keeps the integer to six digits or fewer.

#### Size
A 64-bit number is up to `2^64 - 1`, or  `18,446,744,073,709,551,999`. This is approximately `1.845 * 10^19`.
The global IDs in my solution will be less than `1.024 * 10^19`.

## Verification

My solution achieves the desired performance by avoiding coordination with other nodes, and keeping minimal state. I benchmarked the code on a 2020 MacBook Air. You can see the results in `results/globalidbmark.runner.results`. Each line shows the number of microseconds it took to spawn a helper process and to request 1,000,000 IDs. The minimum runtime was 3,650,234 microseconds (273,955 requests/second). The maximum runtime was 4,706,357 microseconds (212,479 requests/second). Each of these met the 100,000 request/second performance requirements.

The benchmark code is in `bmark/global_id_bmark.ex`. You can run benchmarks with `mix bmark`.

I also added one normal unit test to make sure all global IDs are unique when we request 10,000,000 of them.

In addition, there are three property-based tests to verify that we meet the throughput, uniqueness, size, and type requirements.

You can learn more about how I approach stateless property-based testing in my ElixirConf 2018 talk [here](https://youtu.be/OVLTHGaTi7k).

You can run the unit test and the property-based tests with `mix test`.

I implemented this code with an `Agent`, as well. The performance was not as good, but it still satisfied the throughput requirement. You can see that code on the `agent` branch in the Git repo. I used the Agent in a way that was local to a node, rather than in a distributed way.

## Resilience

Here are some ways things could go wrong.

1. Node crashes
2. System failure
3. Software defects
4. Slowdowns due to resource consumption
5. Process crashes

### Node crashes

As long as the node takes one or more seconds to come back online, the code guarantees uniqueness. The process that tracks the state will restart the state integer at 0.

### System failure

My solution does not rely on coordination between nodes. If the entire system does down, we can guarantee uniqueness if each node in the system takes one or more seconds to restart.

### Software defects

If the real implementation of the timestamp generator does not compensate for time warps, we could end up with multiple global IDs that are the same. My implementation assumes that this will not happen. However, if we had to account for the possibility of time warps, we could keep the latest global ID in state. We could check the new global ID against the last one to make sure the new one is larger. If it wasn't, we could add some code to increase the new value to compensate for the discrepancy.

### Slowdowns due to resource consumption

The memory consumption was fairly constant in the benchmarks because the recursive function is tail-call optimized. The CPU usage was fairly high, though. If another process on the node started consuming CPU resources heavily, this could cause the `GlobalId.get_id/1` function to slow down. The host operating system could also run something else that consumes CPU resources. Either of these could cause a severe enough slowdown that results in fewer than 100,000 requests/second being processed.

Adding monitoring to the system, along with some logic to redirect traffic away from the resource-starved node, could help mitigate this problem.

### Process crashes

The process containing the program state could crash. A supervisor could bring that process back up very quickly. The initialization would need to ensure that the process didn't restart too quickly, though, to prevent duplicate global IDs. Depending on the system requirements, this may be an acceptable tradeoff in order to keep the global ID code simple. However, one second may be an unacceptable delay. A one-second delay could mean our node returns 100,000 error responses. To compensate for this, we could instruct the system to monitor the node's responses, and to shift traffic to another node if there were enough errors in a short time window. Retry logic or a circuit breaker could also help.

If we wanted our code to respond to a restart in under one second, we could try reformatting our global ID integer. The timestamp could come last, and could include milliseconds. We could try to combine the node ID and our state integer into the remaining digits available to us. We would then prefix those to the timestamp. This would let us have our new process serving requests in 1ms instead of 1s.
