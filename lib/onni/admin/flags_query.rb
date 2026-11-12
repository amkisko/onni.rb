# frozen_string_literal: true

module Onni
  module Admin
    # Filters and pages registry flags for the ActiveAdmin Features index.
    class FlagsQuery
      DEFAULT_PER_PAGE = 25
      PER_PAGE_OPTIONS = [10, 25, 50, 100].freeze
      SCOPES = %w[all enabled disabled].freeze
      DEFAULT_SCOPE = "all"

      def initialize(params = {})
        source = params.presence || {}
        @params = {
          q: source[:q],
          scope: source[:scope],
          expires: source[:expires],
          per: source[:per],
          page: source[:page]
        }.with_indifferent_access
      end

      def flags
        @flags ||= filter_scope(pre_scope_flags)
      end

      def page
        @page ||= begin
          scope = flags
          if defined?(Kaminari)
            Kaminari.paginate_array(scope).page(@params[:page]).per(per_page)
          else
            scope
          end
        end
      end

      def search
        @params[:q].to_s.strip
      end

      def scope
        value = @params[:scope].to_s
        SCOPES.include?(value) ? value : DEFAULT_SCOPE
      end

      def expires_filter
        @params[:expires].to_s
      end

      def per_page
        value = @params[:per].to_i
        PER_PAGE_OPTIONS.include?(value) ? value : DEFAULT_PER_PAGE
      end

      def filter_params
        {
          q: search.presence,
          scope: (scope == DEFAULT_SCOPE) ? nil : scope,
          expires: expires_filter.presence,
          per: per_page
        }.compact
      end

      def scope_counts
        base = pre_scope_flags
        enabled = base.count { |flag| flag.enabled?(record_stats: false) }
        {
          "all" => base.size,
          "enabled" => enabled,
          "disabled" => base.size - enabled
        }
      end

      private

      def all_flags
        @all_flags ||= Onni::Registry.config.keys.sort.map { |key| Onni::Flag.new(key) }
      end

      def pre_scope_flags
        @pre_scope_flags ||= filter_expires(filter_search(all_flags))
      end

      def filter_search(list)
        query = search.downcase
        return list if query.blank?

        list.select do |flag|
          flag.name.downcase.include?(query) || flag.description.to_s.downcase.include?(query)
        end
      end

      def filter_scope(list)
        case scope
        when "enabled"
          list.select { |flag| flag.enabled?(record_stats: false) }
        when "disabled"
          list.reject { |flag| flag.enabled?(record_stats: false) }
        else
          list
        end
      end

      def filter_expires(list)
        case expires_filter
        when "with"
          list.select { |flag| flag.expires_on }
        when "without"
          list.reject { |flag| flag.expires_on }
        when "past"
          today = Time.now.utc.to_date
          list.select { |flag| flag.expires_on && flag.expires_on < today }
        else
          list
        end
      end
    end
  end
end
