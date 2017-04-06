module WssAgent
  class Configure
    DEFAULT_CONFIG_FILE = 'default.yml'.freeze
    CUSTOM_DEFAULT_CONFIG_FILE = 'custom_default.yml'.freeze
    CURRENT_CONFIG_FILE = 'wss_agent.yml'.freeze
    API_PATH = '/agent'.freeze

    extend SingleForwardable
    def_delegator :current, :[]

    class << self
      def default_path
        File.join(
          File.expand_path('../..', __FILE__), 'config', DEFAULT_CONFIG_FILE
        )
      end

      def custom_default_path
        File.join(
          File.expand_path('../..', __FILE__), 'config',
          CUSTOM_DEFAULT_CONFIG_FILE
        )
      end

      def exist_default_config?
        File.exist?(default_path)
      end

      def default
        exist_default_config? ? Psych.safe_load(File.read(default_path)) : {}
      end

      def current_path
        Bundler.root.join(CURRENT_CONFIG_FILE).to_s
      end

      def current
        unless File.exist?(current_path)
          return raise NotFoundConfigFile, WssAgentError::NOT_FOUND_CONFIGFILE
        end

        @current_config = Psych.safe_load(File.read(current_path))

        unless @current_config
          return raise InvalidConfigFile, WssAgentError::INVALID_CONFIG_FORMAT
        end

        default.merge(@current_config)
      end

      def uri
        @url = current['url']
        if @url.nil? || @url == ''
          raise ApiUrlNotFound, WssAgentError::CANNOT_FIND_URL
        end
        URI(@url)

      rescue URI::Error
        raise ApiUrlInvalid, WssAgentError::URL_INVALID
      end

      def port
        uri.port || 80
      end

      def url
        @uri = uri
        [@uri.scheme, @uri.host].join('://')
      end

      def ssl?
        uri.scheme == 'https'
      end

      def api_path
        @uri = uri
        @url_path = @uri.path
        @url_path == '' ? API_PATH : @url_path
      end

      def token
        if current['token'].nil? || (current['token'] == '') ||
           (current['token'] == default['token'])
          raise TokenNotFound, WssAgentError::CANNOT_FIND_TOKEN
        else
          current['token']
        end
      end

      def project_meta
        @project_meta ||= WssAgent::Project.new
      end

      def coordinates
        return {} unless current['project_token'].to_s.strip.empty?
        coordinates_config = current['coordinates']
        coordinates_artifact_id = coordinates_config['artifact_id']
        coordinates_version = coordinates_config['version']
        if coordinates_artifact_id.to_s.strip.empty?
          coordinates_artifact_id = project_meta.project_name
          coordinates_version = project_meta.project_version
        end
        { 'artifactId' => coordinates_artifact_id,
          'version' => coordinates_version }
      end
    end
  end
end
