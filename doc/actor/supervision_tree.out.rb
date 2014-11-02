require 'concurrent'                               # => true

logger                          = Logger.new($stderr) 
Concurrent.configuration.logger = lambda do |level, progname, message = nil, &block|
  logger.add level, message, progname, &block
end 


class Master < Concurrent::Actor::RestartingContext
  def initialize
    # for listener to be child of master
    @listener = Listener.spawn(name: 'listener1', supervise: true, args: [self])
  end

  def on_message(msg)
    case msg
    when :listener
      @listener
    when :reset, :terminated, :resumed, :paused
      log Logger::DEBUG, " got #{msg} from #{envelope.sender}"
    else
      pass
    end
  end

  # TODO turn this into Behaviour and make it default part of RestartingContext
  def on_event(event)
    case event
    when :resetting, :restarting
      @listener << :terminate!
    when Exception, :paused
      @listener << :pause!
    when :resumed
      @listener << :resume!
    end
  end
end 

class Listener < Concurrent::Actor::RestartingContext
  def initialize(master)
    @number = (rand() * 100).to_i
  end

  def on_message(msg)
    case msg
    when :number
      @number
    else
      pass
    end
  end

end 

master   = Master.spawn(name: 'master', supervise: true)
    # => #<Concurrent::Actor::Reference:0x7fbe491a71b0 /master (Master)>
listener = master.ask!(:listener)
    # => #<Concurrent::Actor::Reference:0x7fbe4919ceb8 /master/listener1 (Listener)>
listener.ask!(:number)                             # => 92

master << :crash
    # => #<Concurrent::Actor::Reference:0x7fbe491a71b0 /master (Master)>

sleep 0.1                                          # => 0

# ask for listener again, old one is terminated
listener.ask!(:terminated?)                        # => true
listener = master.ask!(:listener)
    # => #<Concurrent::Actor::Reference:0x7fbe49175bd8 /master/listener1 (Listener)>
listener.ask!(:number)                             # => 99

master.ask!(:terminate!)                           # => true

sleep 0.1                                          # => 0
