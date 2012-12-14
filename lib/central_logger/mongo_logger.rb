module CentralLogger
  class MongoLogger < ActiveSupport::BufferedLogger

    ## Mixins

    include CentralLogger::Constants

    ## Instance Readers

    attr_reader :connected
    attr_reader :configuration
    attr_accessor :level

    def initialize(options = {})
      path = options[:path] || File.join(Rails.root, "log/#{Rails.env}.log")
      @level = level = options[:level] || Severity::DEBUG

      # Attempt to setup the mongodb logger connection.
      @connected = false
      begin
        configure
        check_for_collection

        if disable_file_logging?
          @buffer        = {}
          @guard = Mutex.new
        end

        @connected = true

      rescue Exception => e
        super(path, level)
        puts "Using BufferedLogger due to exception: #{e.inspect}"
        add Severity::ERROR, e.to_s
        add Severity::ERROR, e.backtrace.join("\n")
        raise e
      end

      # Only enable file logging if specified.
      unless disable_file_logging?
        super(path, level)
      end

    # Enable file loggin on any errors.
    rescue Exception => e
      super(path, level)
    end

    def add_metadata(options={})
      options.each_pair do |key, value|
        unless [:messages, :request_time, :ip, :runtime, :application_name].include?(key.to_sym)
          @mongo_record[key] = value
        else
          raise ArgumentError, ":#{key} is a reserved key for the central logger. Please choose a different key"
        end
      end
    end

    def add(severity, message = nil, progname = nil, &block)
      if @connected && @level <= severity && message.present?

        # Create the hash of message data to be saved.
        msg_h = {
          :t => Time.now.getutc,
          :m => message,
          :s => log_levels[severity],
        }

        # Add a special message with severity.
        if @combine_request && @mongo_record.present?
          @mongo_record[:ms] << msg_h
        end

        # Add in program name information
        if progname.nil?
          msg_h[:progname] = @application_name
        else
          msg_h[:progname] = progname
        end

        # Add a normal message for every composite message
        if @individual_lines
          LogMessage.with(safe: @safe_insert, validate: false, async: true).create!(msg_h)
        end

      end

      # If file logging has been disabled then simply return the message
      # otherwise call super.
      if @connected
        disable_file_logging? ? message : super
      else
        super
      end
    end

    # Drop the capped_collection and recreate it
    def reset_collection
      LogMessage.collection.drop
      create_collection
    end

    # This method is used to capture messages as part of a full request.
    def mongoize(options = {})
      create_new_record(options)
      runtime = Benchmark.measure{ yield }.real if block_given?
    rescue Exception => e
      add(3, e.message + "\n" + e.backtrace.join("\n"))
      # Re-raise the exception for anyone else who cares
      raise e
    ensure
      # In case of exception, make sure runtime is set
      @mongo_record[:runtime] = ((runtime ||= 0) * 1000).ceil
      begin
        @insert_block.call
      rescue
        # do extra work to inpect (and flatten)
        force_serialize @mongo_record
        @insert_block.call rescue nil
      end
    end

    private

    def configure
      @configuration = {
        'cap_data_size' => Rails.env.production? ? PRODUCTION_COLLECTION_SIZE : DEFAULT_COLLECTION_SIZE,
        'cap_object_num' => Rails.env.production? ? PRODUCTION_NUM_OBJECTS : DEFAULT_NUM_OBJECTS,
      }.merge(resolve_config)

      Mongoid.load!(Rails.root.join("config", "mongoid.yml"), Rails.env)

      @safe_insert = @configuration['safe_insert'] || false
      @combine_request = @configuration.fetch('combine_request', true)
      @individual_lines = @configuration.fetch('individual_lines', false)
      resolve_application_name

      @insert_block = lambda { insert_log_record(@safe_insert) }
    end

    # @return hash of the log levels mapped from constants from lookup reverse
    #   mapped required later.
    def log_levels
      @log_level_hash ||= ActiveSupport::BufferedLogger::Severity.constants.inject({}) do |h, v|
        h[ActiveSupport::BufferedLogger::Severity.const_get(v.to_s)] = v.to_s
        h
      end
    end

    def disable_file_logging?
      @disable_file_logging ||= @configuration.fetch('disable_file_logging', false)
    end

    # @return [String] the name of the application determined once at runtime.
    def resolve_application_name
      return @application_name if @application_name

      if @configuration.has_key?('application_name')
        @application_name = @configuration['application_name']
      elsif Rails::VERSION::MAJOR >= 3
        @application_name = Rails.application.class.to_s.split("::").first
      else
        # rails 2 requires detective work if it's been deployed by capistrano
        # if last entry is a timestamp, go back 2 dirs (ex. /app_name/releases/20110304132847)
        path = Rails.root.to_s.split('/')
        @application_name = path.length >= 4 && path.last =~ /^\d/ ? path.last(3)[0] : path.last
      end
    end

    def resolve_config
      config = {}
      CONFIGURATION_FILES.each do |filename|
        config_file = Rails.root.join("config", filename)
        if config_file.file?
          config = YAML.load(File.read(config_file))[Rails.env]
          config = config['mongo'] if config.has_key?('mongo')
          break
        end
      end
      config
    end

    def create_collection
      if !!@configuration['cap_object_num']
        LogMessage.mongo_session.with(safe: true, database: LogMessage.collection.database.name) do |session|
          session.command({
            create: LogMessage.collection.name,
            capped: true,
            size: @configuration['cap_data_size'],
            max: @configuration['cap_object_num']
          })
        end
      end
    end

    # Setup the capped collection if it doesn't already exist.
    def check_for_collection
      unless LogMessage.mongo_session.collections.map{ |c| c.name.to_s }.include?(Unroole::MeteredDataCounter.collection.name.to_s)
        create_collection
      end
    end

    # Creates a new combined record.
    def create_new_record(options = {})
      @mongo_record = LogMessage.new(options.merge({
        :messages => [],
        :time => Time.now.getutc,
        :progname => resolve_application_name,
        :combined => true
      }))
    end

    # Insert a new record on rewquest end.
    def insert_log_record(safe = false)
      @mongo_record.with(safe: safe, validate: false, async: true).save!
      create_new_record
    end

    # force the data in the db by inspecting each top level array and hash element
    # this will flatten other hashes and arrays
    def force_serialize(rec)
      if msgs = rec[:message]
        msgs.collect! { |j| j.inspect }
      end

      if pms = rec[:params]
        pms.each { |i, j| pms[i] = j.inspect }
      end
    end

  end
end
