module Padrino
  module Warden
    module Helpers

      # The main accessor to the warden middleware
      def warden
        request.env['warden']
      end

      # Return session info
      #
      # @param [Symbol] the scope to retrieve session info for
      def session_info(scope=nil)
        scope ? warden.session(scope) : scope
      end

      # Check the current session is authenticated to a given scope
      def authenticated?(scope=nil)
        scope ? warden.authenticated?(scope) : warden.authenticated?
      end
      alias_method :logged_in?, :authenticated?

      # Authenticate a user against defined strategies
      def authenticate(*args)
        warden.authenticate!(*args)
      end
      alias_method :login, :authenticate

      # Terminate the current session
      #
      # @param [Symbol] the session scope to terminate
      def logout(scopes=nil)
        scopes ? warden.logout(scopes) : warden.logout
      end

      # Access the user from the current session
      #
      # @param [Symbol] the scope for the logged in user
      def user(scope=nil)
        scope ? warden.user(scope) : warden.user
      end
      alias_method :current_user, :user

      # Store the logged in user in the session
      #
      # @param [Object] the user you want to store in the session
      # @option opts [Symbol] :scope The scope to assign the user
      # @example Set John as the current user
      #   user = User.find_by_name('John')
      def user=(new_user, opts={})
        warden.set_user(new_user, opts)
      end
      alias_method :current_user=, :user=

    end

    def self.registered(app)
      app.helpers Helpers

      # Enable Sessions
      app.set :sessions, true
      app.set :auth_failure_path, '/'
      app.set :auth_success_path, '/'
      # Setting this to true will store last request URL
      # into a user's session so that to redirect back to it
      # upon successful authentication
      app.set :auth_use_referrer, false
      app.set :auth_error_message,   "Could not log you in."
      app.set :auth_success_message, "You have logged in successfully."
      app.set :auth_login_template, 'sessions/login'
      app.set :auth_login_layout, 'layouts/layout'
      # OAuth Specific Settings
      app.set :auth_use_oauth, false
      
      app.use ::Warden::Manager do |manager|
          manager.scope_defaults :default, 
            strategies: [:password], 
            action: 'session/unauthenticated'
          manager.failure_app = app
      end
      
      app.controller :sessions do
        post :unauthenticated  do
          status 401
          warden.custom_failure! if warden.config.failure_app == self.class
          flash.now[:error] = settings.auth_error_message if flash
          render settings.auth_login_template
        end

        get :login do
          if settings.auth_use_oauth && !@auth_oauth_request_token.nil?
            session[:request_token] = @auth_oauth_request_token.token
            session[:request_token_secret] = @auth_oauth_request_token.secret
            redirect @auth_oauth_request_token.authorize_url
          else
            render settings.auth_login_template, :layout => settings.auth_login_layout
          end
        end

        get :oauth_callback do
          if settings.auth_use_oauth
            authenticate
            flash[:success] = settings.auth_success_message if flash
            redirect settings.auth_success_path
          else
            redirect settings.auth_failure_path
          end
        end

        post :login do
          authenticate
          flash[:success] = settings.auth_success_message if flash
          redirect settings.auth_use_referrer && session[:return_to] ? session.delete(:return_to) : 
                   settings.auth_success_path
        end

        get :logout do
          logout
          flash[:success] = settings.auth_success_message if flash
          redirect settings.auth_success_path
        end
      end
    end
  end # Warden
end # Padrino
