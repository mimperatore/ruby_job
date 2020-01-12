[![Code Climate](https://codeclimate.com/github/mimperatore/ruby_job.svg)](https://codeclimate.com/github/mimperatore/ruby_job)
[![Test Coverage](https://codeclimate.com/github/mimperatore/ruby_job/badges/coverage.svg)](https://codeclimate.com/github/mimperator/ruby_job/coverage)
[![Build Status](https://travis-ci.com/mimperatore/ruby_job.svg?branch=master)](https://codecov.io/gh/mimperatore/ruby_job/branch/master)

# RubyJob

RubyJob is a framework for running jobs.

The current version behaves much like [Sucker Punch](https://github.com/brandonhilkert/sucker_punch), in that it
only supports an [In-Memory Job Store](https://github.com/mimperatore/ruby_job/blob/master/lib/ruby_job/in_memory_job_store.rb)
implemented through a fast [Fibonacci Heap](https://github.com/mudge/fibonacci_heap).

The initial version, which supports only a single queue, runs **200% faster than Sucker Punch**, capable of processing **1,000,000** simple jobs in **28 seconds**
vs. Sucker Punch's 59 seconds (measured on a MacBook Pro 2.3GHz with 16GB of RAM).

Additional features are in the works, including:
- Support for multiple queues & queue priorities
- Persistent Job Stores for:
  - Redis
  - Cassandra
- Batches & Job nesting

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruby_job'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ruby_job

## Usage

### A simple example

#### Define your worker class
```ruby
class MyWorker
  include RubyJob::Worker

  def perform
    #job code goes here
  end
end
```

#### Setup your JobStore
```ruby
MyWorker.jobstore = RubyJob::InMemoryJobStore.new
MyWorker.perform_async
```

#### Run your server
```ruby
server = RubyJob::ThreadedServer.new(num_threads: 10, jobstore: MyWorker.jobstore)
server_thread = server.start
server_thread.join
```

### Setting up the default JobStore
Jobs are enqueued to the default JobStore of the worker class:

```ruby
MyWorker.jobstore = RubyJob::InMemoryJobStore.new # attach the JobStore to the MyWorker class
```

If the worker class doesn't have a JobStore attached to it, jobs will be enqueued to `Worker.jobstore`.

```ruby
Worker.jobstore = RubyJob::InMemoryJobStore.new # jobs will be queued here, if MyWorker doesn't have `jobstore` set.
```

### Enqueuing jobs
There are 2 ways you can enqueue your jobs:

#### Using <i>#perform_*</i> (recommended approach)
```ruby
MyWorker.jobstore = RubyJob::InMemoryJobStore.new
MyWorker.perform_async # will enqueue on `MyWorker.jobstore`, or `Worker.jobstore` if the former isn't set.
```

**Note:** you must ensure either `MyWorker.jobstore` or `Worker.jobstore` is set to a valid JobStore.

#### Using Job#enqueue
```ruby
MyWorker.jobstore = RubyJob::InMemoryJobStore.new
job = Job.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now)
job.enqueue
```

### Dequeuing jobs
In some situations, it's important to remove a previously enqueued job from the queue, so that it does not run in the future.
To do so:
```ruby
job.dequeue
```

### Job arguments
Your Job class' `#perform` method signature is:
```ruby
  def perform(*args)
  end
```

When you invoke `#perform_async` (or similar methods), the arguments passed in will get sent to `#perform`.

For example, `MyWorker.perform_async(1, 'hello world!', x: 7)` will end up calling `perform(1, 'hello world!', x: 7)` when the job runs.

**Note**: Whether and how the arguments are serialized depends on the JobStore being used.  `RubyJob::InMemoryJobStore`, the only JobStore
currently shipped out of the box with this gem, has no need to serialize the arguments, given that everything runs in a single operating system
process.  However, keep in mind that the `Job` class, which is used to represent instances of jobs to run, defines methods `#to_json` and
`.json_create(hash)` which use `JSON.dump` and `JSON.parse`, respectively, to marshall the arguments.  If you're going to implement
your own JobStore, feel free to avail yourself of these methods.

**Pro Tip**: In order to ensure your job code is portable across different JobStore implementations (e.g. in case at some point you think
you'll need a persistent backing store such as Redis or Cassandra to keep track of your mission critical jobs), ensure the arguments
you pass serialize and deserialize as you'd expect.

### Schedule a Job for execution (asynchronously)

**Note:** Jobs are scheduled to nearest **millisecond** of the specified start time.

#### Immediately (ASAP)
```ruby
MyWorker.perform_async # schedule to run asynchonously, asap
```

#### Delayed
```ruby
MyWorker.perform_in(5.5) # schedule to run asynchonously, in 5.5 seconds
```

#### At a specific time
```ruby
MyWorker.perform_at(a_particular_time) # schedule to run asynchonously, at the specified time
```

### Executing a Job immediately (synchronously)
```ruby
MyWorker.perform # run the job synchronously now
```

### Threaded Server (the job processor)
A threaded server is provided to process the queued jobs.  It is instantiated by specifying the number of workers (threads) to spawn,
and the JobStore it will be processing.
```ruby
server = RubyJob::ThreadedServer.new(num_threads: 10, jobstore: MyWorker.jobstore)
```

#### Server options
```ruby
server.set(wait: true, wait_delay: 0.5)
```

- `wait`[boolean]: determines whether the server should wait or exit when there aren't any processable jobs in the queue.  Defaults to `true`.
- `wait_delay`[float]: if the server is going to wait, the number of seconds to delay before looking for jobs again.  Defaults to `0.5`.

**Note:** The `wait`/`wait_delay` parameters apply independently to each worker thread.

#### Starting the server
Queued jobs will only run when a Server, attached to the JobStore the jobs have been enqueued to, has been started.

```ruby
server_thread = server.start
server_thread.join # if needed, depending on your use case
```

#### Halting the server
A running server can be halted as follows:
```ruby
server.halt_at(Time.now + 5)
```

```ruby
server.halt # equivalent to halt_at(Time.now)
```

`Halting` causes the server to stop processing jobs scheduled to start after the specified halt time. Once the halt time has been
reached, the server waits if the `wait` option is `true`, or exits otherwise.

Halting the server can be useful in production, when you want to temporarily pause job processing.

#### Resuming the server
A halted server can be resumed with:
```ruby
server.resume
```

```ruby
server.resume_until(Time.now + 5) # equivalent to: resume && halt_at(Time.now + 5)
```

With `resume`, the server picks up jobs from where it left off and keeps processing them as if it never stopped.  Note that a server
that's been halted for a significant amount of time will pick up old jobs that may have been intended to start significantly in the past, so
ensure you take that into account in your job processing code if you care about this situation.

### Retries
By default, jobs that raise errors will be not be retried by default.  To have jobs retry, the worker class must define a `retry?` method that
returns a tuple indicating whether the job should be retried, and how long the retry delay should be: `[do_retry, retry_delay]`
```ruby
  MAX_RETRIES = 5
  INITIAL_RETRY_DELAY = 0.5

  def retry?(attempt:, error:)
    # determine whether a retry is required, based on the attempt number and error passed in
    do_retry = error.is_a?(MyRetriableError) && (attempt < MAX_RETRIES)

    [do_retry, INITIAL_RETRY_DELAY * 2**(attempt-1)] # exponential backoff
  end
```

`attempt` starts at `1` and `error` is the exception that was raised by the last attempt.

**Note:** the current implementation uses `sleep` to implement the retry delay.  This isn't ideal, as it prevents the thread
processing the job from servicing another job that's ready to run.  In the future, this will be changed such that the job
is put back onto the job queue to start at a later time.  Feel free to put together a PR if you're interested in seeing this
change sooner rather than later.

**Note:** the retry delay is the time between the end of the last attempt and the start of the new attempt

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and
then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mimperatore/ruby_job. This project is intended to be a safe, welcoming space
for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [GNU Lesser General Public License Version 3 (LGPLv3)](https://www.gnu.org/licenses/lgpl-3.0.html).

## Code of Conduct

Everyone interacting in the RubyJob project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow
the [code of conduct](https://github.com/mimperatore/ruby_job/blob/master/CODE_OF_CONDUCT.md).
