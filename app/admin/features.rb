# frozen_string_literal: true

require "onni/admin/flags_query"

ActiveAdmin.register_page "Features" do
  menu priority: 3, label: proc { I18n.t("onni.menu", default: "Features") },
    if: proc { instance_exec(&Onni.configuration.admin_authorized) }

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
            column("Enabled globally") { |flag| status_tag(flag.enabled?(record_stats: false) ? "Yes" : "No") }
            column("Gates") do |flag|
              names = flag.gates.map { |gate| gate["key"] }
              names.presence&.join(", ") || "—"
            end
            column("Actions") do |flag|
              if flag.enabled?(record_stats: false)
                button_to "Disable", admin_features_disable_path(key: flag.name),
                  method: :post,
                  class: "bg-red-500 hover:bg-red-700 text-white hover:text-white action-item-button"
              else
                button_to "Enable", admin_features_enable_path(key: flag.name),
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
              column("Enabled globally") { |flag| status_tag(flag.enabled?(record_stats: false) ? "Yes" : "No") }
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

  page_action :enable, method: :post do
    Onni.enable(params.require(:key))
    redirect_to admin_features_path, notice: "Enabled #{params[:key]}"
  end

  page_action :disable, method: :post do
    Onni.disable(params.require(:key))
    redirect_to admin_features_path, notice: "Disabled #{params[:key]}"
  end

  page_action :feature, method: :get do
    range = params.fetch(:range, "24h")
    next head(:bad_request) unless Onni::HitChart::WINDOWS.key?(range)

    @flag = Onni::Flag.new(params.require(:key))
    @hit_chart = Onni::HitChart.new(@flag.name, range: range)
    @page_title = @flag.name
    render "admin/features/show", layout: "active_admin"
  end

  page_action :update_feature, method: :post do
    key = params.require(:key)
    feature_params = params[:feature].presence || params
    percentage = feature_params[:percentage].presence
    Onni.enable_percentage_of_actors(key, percentage.to_i) if percentage
    if feature_params[:control].present? || feature_params[:treatment].present? || params[:variants].present?
      variants =
        if params[:variants].present?
          params[:variants].to_unsafe_h.transform_values(&:to_i)
        else
          {
            "control" => feature_params[:control].to_i,
            "treatment" => feature_params[:treatment].to_i
          }
        end
      variants = variants.reject { |_name, weight| weight.to_i <= 0 }
      Onni.set_variants(key, variants) if variants.any?
    end
    group_action = feature_params[:group_action]
    group_name = feature_params[:group_name]
    case group_action
    when "enable"
      Onni.enable_group(key, group_name) if group_name.present?
    when "disable"
      Onni.disable_group(key, group_name) if group_name.present?
    end
    redirect_to onni_feature_path(key), notice: "Updated #{key}"
  end
end
