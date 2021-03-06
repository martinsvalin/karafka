module Karafka
  # Class used to catch signals from ruby Signal class in order to manage Karafka shutdown
  # @note There might be only one monitor - this class is a singleton
  class Monitor
    include Singleton

    # Signal types that we handle
    HANDLED_SIGNALS = %i(
      SIGINT SIGQUIT
    )

    HANDLED_SIGNALS.each do |signal|
      # Assigns a callback that will happen when certain signal will be send
      # to Karafka server instance
      # @note It does not define the callback itself -it needs to be passed in a block
      # @example Define an action that should be taken on_sigint
      #   monitor.on_sigint do
      #     Karafka.logger.info('Log something here')
      #     exit
      #   end
      define_method :"on_#{signal.to_s.downcase}" do |&block|
        @callbacks[signal] << block
      end
    end

    # Creates an instance of monitor and creates empty hash for callbacks
    def initialize
      @callbacks = {}
      HANDLED_SIGNALS.each { |signal| @callbacks[signal] = [] }
    end

    # Method catches all HANDLED_SIGNALS and performs appropriate callbacks (if defined)
    # @note If there are no callbacks, this method will just ignore a given signal that was sent
    # @param [Block] block of code that we want to execute and supervise
    def supervise(&block)
      HANDLED_SIGNALS.each { |signal| trap_signal(signal) }
      block.call
    end

    private

    # Traps a single signal and performs callbacks (if any) or just ignores this signal
    # @param [Symbol] signal type that we want to catch
    def trap_signal(signal)
      trap(signal) do
        log_signal(signal)
        (@callbacks[signal] || []).each(&:call)
      end
    end

    # Logging into Karafka.logger error with signal code
    # @param [Symbol] signal type that we received
    # @note We cannot perform logging from trap context, that's why
    #   we have to spin up a new thread to do this
    def log_signal(signal)
      Thread.new do
        Karafka.logger.info("Received system signal #{signal}")
      end
    end
  end
end
