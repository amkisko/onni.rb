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

    panel "Dashboard" do
      para "Experiments and feature flags: actor/group targeting, percentage rollout, A/B variants, conditions, and hit stats for analysis."
      para "Onni is not an authorization system. Protect privileged actions in your host policy layer."
      para "Import from another feature-flag library with Onni.migrate!(source), then use the controls below."
    end

    panel "Hit storage" do
      para "Buckets: #{overview[:bucket_count]}"
      para "Oldest hour: #{overview[:oldest_period_start] || "—"}"
      retention = overview[:retention]
      para "Retention: #{retention ? "#{(retention / 1.day).to_i} days" : "not set"}"
      para "Sample rate: #{overview[:sample_rate]}"
      if overview[:past_retention]
        para "Oldest hit history is past retention. Run scheduled cleanup."
      end
      if overview[:large_table]
        para "Hit storage is large. Confirm daily cleanup is scheduled."
      elsif overview[:bucket_count].positive?
        para "Keep cleanup scheduled daily so hit history does not grow without bound."
      else
        para "No hit buckets yet. After traffic starts, schedule daily cleanup."
      end
    end

    panel "Flags" do
      table_for flags do
        column("Key") { |flag| link_to flag.name, admin_features_feature_path(key: flag.name) }
        column("Description", &:description)
        column("Expires") { |flag| flag.expires_at }
        column("Enabled globally") { |flag| status_tag(flag.enabled?(record_stats: false)) }
        column("Gates") { |flag| flag.gates.map { |gate| "#{gate["key"]}=#{gate["value"]}" }.join(", ").presence || "—" }
        column("Actions") do |flag|
          span button_to("Enable", admin_features_enable_path(key: flag.name), method: :post)
          span button_to("Disable", admin_features_disable_path(key: flag.name), method: :post)
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
