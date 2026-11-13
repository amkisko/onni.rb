# frozen_string_literal: true

require "onni/admin/flags_query"

ActiveAdmin.register_page "Features" do
  menu priority: 3, label: proc { I18n.t("onni.menu", default: "Flags") },
    if: proc { instance_exec(&Onni.configuration.admin_authorized) }

  breadcrumb do
    links = [link_to("Admin", admin_root_path)]
    links << link_to(I18n.t("onni.menu", default: "Flags"), admin_features_path) unless action_name == "index"
    links
  end

  controller do
    before_action :onni_require_admin!

    helper_method :onni_feature_path

    private

    def onni_require_admin!
      return if instance_exec(&Onni.configuration.admin_authorized)

      head :forbidden
    end

    def onni_feature_path(key, **options)
      Onni::ActiveAdminRoutes.feature_path_helper(view_context, key, **options)
    end
  end

  action_item :stats_storage, only: :index do
    link_to "Stats storage", admin_features_stats_path, class: "action-item-button"
  end

  sidebar "Filters", only: :index do
    query = Onni::Admin::FlagsQuery.new(params)

    h3 I18n.t("active_admin.sidebars.filters", default: "Filters"), class: "filters-form-title"

    text_node helpers.form_tag(helpers.admin_features_path, method: :get, class: "filters-form") {
      helpers.safe_join([
        (helpers.hidden_field_tag(:scope, query.scope) unless query.scope == Onni::Admin::FlagsQuery::DEFAULT_SCOPE),
        helpers.tag.div(class: "filters-form-field") {
          helpers.safe_join([
            helpers.label_tag(:q, "Search"),
            helpers.text_field_tag(:q, query.search, id: "q")
          ])
        },
        helpers.tag.div(class: "filters-form-field") {
          helpers.safe_join([
            helpers.label_tag(:expires, "Expires"),
            helpers.select_tag(
              :expires,
              helpers.options_for_select(
                [
                  ["Any", ""],
                  ["With expiry", "with"],
                  ["Without expiry", "without"],
                  ["Past expiry", "past"]
                ],
                query.expires_filter
              ),
              id: "expires"
            )
          ])
        },
        helpers.tag.div(class: "filters-form-field") {
          helpers.safe_join([
            helpers.label_tag(:per, "Per page"),
            helpers.select_tag(
              :per,
              helpers.options_for_select(
                Onni::Admin::FlagsQuery::PER_PAGE_OPTIONS,
                query.per_page
              ),
              id: "per"
            )
          ])
        },
        helpers.tag.div(class: "filters-form-buttons") {
          helpers.safe_join([
            helpers.submit_tag(
              I18n.t("active_admin.filters.buttons.filter", default: "Filter"),
              class: "filters-form-submit"
            ),
            helpers.link_to(
              I18n.t("active_admin.filters.buttons.clear", default: "Clear Filters"),
              helpers.admin_features_path,
              class: "filters-form-clear"
            )
          ])
        }
      ].compact)
    }
  end

  content title: "Flags" do
    query = Onni::Admin::FlagsQuery.new(params)
    collection = query.page
    tab_params = query.filter_params.except(:scope)
    counts = query.scope_counts

    div class: "scopes mb-4", role: "toolbar" do
      div class: "index-button-group", role: "group" do
        Onni::Admin::FlagsQuery::SCOPES.each do |scope_id|
          label = (scope_id == "all") ? "All" : scope_id.capitalize
          classes = ["index-button"]
          classes << "index-button-selected" if query.scope == scope_id
          a href: helpers.admin_features_path(tab_params.merge(scope: (scope_id == "all") ? nil : scope_id).compact),
            class: classes.join(" ") do
            text_node label
            span counts.fetch(scope_id), class: "scopes-count"
          end
        end
      end
    end

    if collection.respond_to?(:total_pages)
      paginated_collection(
        collection,
        entry_name: "flag",
        download_links: false,
        param_name: :page,
        params: query.filter_params
      ) do
        div class: "index-as-table" do
          table_for collection do
            column("Key") { |flag| link_to flag.name, helpers.onni_feature_path(flag.name) }
            column("Description", &:description)
            column("Expires") do |flag|
              summary = flag.expires_summary
              if summary
                span summary, title: flag.expires_full, "data-onni-expires": true
              else
                span "—"
              end
            end
            column("Status") { |flag| status_tag(flag.power_state.to_s.capitalize) }
            column("Assignment") { |flag| (flag.type == "experiment") ? "Experiment" : "None" }
            column("Actions") do |flag|
              if flag.ready?
                button_to "Park", admin_features_park_path(key: flag.name),
                  method: :post,
                  class: "bg-red-500 hover:bg-red-700 text-white hover:text-white action-item-button"
              else
                button_to "Ready", admin_features_ready_path(key: flag.name),
                  method: :post,
                  class: "bg-orange-500 hover:bg-orange-700 text-white hover:text-white action-item-button"
              end
            end
          end
        end
      end
    else
      div class: "paginated-collection" do
        div class: "paginated-collection-contents" do
          div class: "index-as-table" do
            table_for collection do
              column("Key") { |flag| link_to flag.name, helpers.onni_feature_path(flag.name) }
              column("Description", &:description)
              column("Status") { |flag| status_tag(flag.power_state.to_s.capitalize) }
            end
          end
        end
      end
    end
  end

  page_action :stats, method: :get do
    @overview = Onni.stats_overview
    @page_title = "Stats storage"
    render "admin/features/stats", layout: "active_admin"
  end

  page_action :ready, method: :post do
    Onni.ready!(params.require(:key))
    redirect_to admin_features_path, notice: "Ready #{params[:key]}"
  rescue KeyError
    head :not_found
  end

  page_action :park, method: :post do
    Onni.park!(params.require(:key))
    redirect_to admin_features_path, notice: "Parked #{params[:key]}"
  rescue KeyError
    head :not_found
  end

  page_action :feature, method: :get do
    range = params.fetch(:range, "24h")
    next head(:bad_request) unless Onni::VisibilityChart::WINDOWS.key?(range)

    next head(:not_found) unless Onni::Registry.known?(params.require(:key))

    @flag = Onni::Flag.new(params.require(:key))
    @visibility_chart = Onni::VisibilityChart.new(@flag.name, range: range)
    @page_title = @flag.name
    render "admin/features/show", layout: "active_admin"
  end

  page_action :update_feature, method: :post do
    key = params.require(:key)
    Onni::RolloutForm.new.apply!(key, params[:feature].presence || params)
    redirect_to onni_feature_path(key), notice: "Updated #{key}"
  rescue ArgumentError, TypeError
    render plain: "Check the rollout settings.", status: 422
  rescue KeyError
    head :not_found
  end
end
