# frozen_string_literal: true

require 'fileutils'

module Scrapyard
  # Imperative shell interfacing between CLI & Yard implementations
  class Runner
    def initialize(yard, pack, log)
      @yard = yard
      @pack = pack
      @log = log
    end

    attr_reader :log

    def initialize_paths(paths)
      log.info "Initializing paths %p" % [paths]
      FileUtils.rmtree paths
      FileUtils.mkdir_p paths
    end

    def search(keys, paths)
      log.info "Searching for %p" % [keys]
      key_paths = Scrapyard::Key.to_keys(keys, @yard.to_path, "", log)

      if (cache = @yard.search(key_paths))
        key = Key.new(cache, @yard.to_path, log)
        @yard.fetch(key)
        @pack.restore(key.local, paths)
        cache
      else
        log.info 'Unable to find key(s): %p' % [keys.map(&:to_s)]
        nil
      end
    end

    def store(keys, paths)
      # store accepts multiple keys but only uses the first, this ensures it's
      # easy to re-use values between search and store.
      key = keys.first
      log.info "Storing #{key}"
      key_path = Scrapyard::Key.new(key + ".tgz", @yard.to_path, log)

      @yard.store(key_path.to_s, @pack.save(key_path.local, paths))
      key_path.to_s
    end

    def junk(keys, _paths)
      log.info "Junking #{keys}"
      key_paths = Scrapyard::Key.to_keys(keys, @yard.to_path, ".tgz", log)
      log.debug "Paths: %p" % key_paths.map(&:to_s)
      @yard.junk(key_paths).map(&:to_s)
    end

    def crush(_keys, _paths)
      @yard.crush
    end
  end
end
