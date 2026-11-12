# frozen_string_literal: true

ActiveAdmin.register_page "Features" do
  menu priority: 3, label: proc { I18n.t("onni.menu", default: "Features") },
    if: proc { instance_exec(&Onni.configuration.admin_authorized) }

  controller do
    before_action :onni_require_admin!

    private

    def onni_require_admin!
      return if instance_exec(&Onni.configuration.admin_authorized)

      head :forbidden
    end
  end

  content title: "Features" do
    flags = Onni::Registry.config.keys.sort.map { |key| Onni::Flag.new(key) }
    overview = Onni.stats_overview
    retention = overview[:retention]

    h3 "Hit storage"
    table class: "onni-hit-storage mb-4" do
      tr do
        th "Buckets"
        th "Oldest hour"
        th "Retention"
        th "Sample rate"
        th "Alerts"
      end
      tr do
        td overview[:bucket_count]
        td(overview[:oldest_period_start] || "—")
        td(retention ? "#{(retention / 1.day).to_i} days" : "not set")
        td overview[:sample_rate]
        td do
          status_tag("Past retention") if overview[:past_retention]
          status_tag("Large table") if overview[:large_table]
          text_node "—" unless overview[:past_retention] || overview[:large_table]
        end
      end
    end

    table_for flags do
      column("Key") { |flag| link_to flag.name, admin_features_feature_path(key: flag.name) }
      column("Description", &:description)
      column("Expires") do |flag|
        summary = flag.expires_summary
        if summary
          span summary, title: flag.expires_full, "data-onni-expires" => true
        else
          span "—"
        end
      end
      column("Enabled globally") { |flag| status_tag(flag.enabled?(record_stats: false)) }
      column("Gates") do |flag|
        names = flag.gates.map { |gate| gate["key"] }
        names.presence&.join(", ") || "—"
      end
      column("Actions") do |flag|
        if flag.enabled?(record_stats: false)
          button_to "Disable", admin_features_disable_path(key: flag.name), method: :post
        else
          button_to "Enable", admin_features_enable_path(key: flag.name), method: :post
        end
      end
    end
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
    render "admin/features/show", layout: "active_admin"
  end

  page_action :update_feature, method: :post do
    key = params.require(:key)
    percentage = params[:percentage].presence
    Onni.enable_percentage_of_actors(key, percentage.to_i) if percentage
    if params[:variants].present?
      variants = params[:variants].to_unsafe_h.transform_values(&:to_i).reject { |_name, weight| weight <= 0 }
      Onni.set_variants(key, variants) if variants.any?
    end
    case params[:group_action]
    when "enable"
      Onni.enable_group(key, params.require(:group_name))
    when "disable"
      Onni.disable_group(key, params.require(:group_name))
    end
    redirect_to admin_features_feature_path(key: key), notice: "Updated #{key}"
  end
end
