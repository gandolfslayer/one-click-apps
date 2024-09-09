#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module API
  module Utilities
    module GrapeHelper
      ##
      # We need this to be able to use `Grape::Middleware::Error#error_response`
      # outside of the Grape context. We use it outside of the Grape context because
      # OpenProject authentication happens in a middleware upstream of Grape.
      class GrapeError < Grape::Middleware::Error
        def initialize(env)
          @env = env
          @options = {}
        end

        def error!(message, status = nil, headers = nil, backtrace = nil, original_exception = nil)
          super
        end
      end

      def grape_error_for(env, api)
        GrapeError.new(env).tap do |e|
          e.options[:content_types] = api.content_types
          e.options[:format] = "hal+json"
        end
      end

      def error_response(rescued_error, error = nil, rescue_subclasses: nil, headers: -> { {} }, log: true)
        error_response_lambda = default_error_response(headers, log)

        response =
          if error.nil?
            error_response_lambda
          else
            lambda { |e| instance_exec error.new(e.message, exception: e), &error_response_lambda }
          end

        # We do this lambda business because #rescue_from behaves differently
        # depending on the number of parameters the passed block accepts.
        rescue_from rescued_error, rescue_subclasses:, &response
      end

      def default_error_response(headers, log)
        lambda { |e|
          original_exception = $!
          representer = error_representer.new e
          resp_headers = instance_exec &headers
          resp_headers["Content-Type"] = error_content_type

          if log == true
            OpenProject.logger.error original_exception, reference: :APIv3
          elsif log.respond_to?(:call)
            log.call(original_exception)
          end

          error!(representer.to_json, e.code, resp_headers)
        }
      end
    end
  end
end
