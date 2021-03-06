class AlertsController < ApplicationController
  before_action :set_alert, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!, except: [:index, :list]
  after_action :expire_alerts_json, only: [:create, :destroy, :update, :upload]


  # GET /alerts
  # GET /alerts.json
  def index
    respond_to do |format|
      format.html do 
        authenticate_user!
        authorize Alert
        @q = Alert.all.ransack(params[:q])
        @alerts = @q.result.order(updated_at: :desc).paginate(page: params[:page])
        @alert = Alert.new
        @alert.alertings.build
      end
      format.json do
        @alerts = Alert.current_or_near_future
        render :index
        cache_page(@response, "/alerts.json")
      end
    end   
  end

  def global
    respond_to do |format|
      format.html do
        authenticate_user!
        authorize Alert
        @alerts = Alert.global.order(updated_at: :desc).paginate(page: params[:page])
        @alert = Alert.new
      end
    end
  end

  # GET /alerts/list.json
  def list
    respond_to do |format|
      format.json do
        features = []
        @global = Alert.global.current_or_near_future
        @locations = Pointsofinterest.with_current_or_near_future_alerts.order(name: :asc) + TrailSystem.with_current_or_near_future_alerts.order(trail_subsystem: :asc)
        render :list
        cache_page(@response, "/alerts/list.json")
      end
    end
  end

  # GET /alerts/1
  # GET /alerts/1.json
  def show
    authorize @alert
  end

  # GET /alerts/new
  def new
    authorize Alert
    @alert = Alert.new
    @alert.alertings.build
    referrer = request.referrer
    #@form_type = referrer.include?('poi')? 'Pointsofinterest' : 'TrailSystem'
  end

  # GET /alerts/1/edit
  def edit
    authorize @alert
    #@alert.alertings.build
  end

  # POST /alerts
  # POST /alerts.json

  def create
    authorize Alert
    @error_div_id = alert_params.delete(:div_id)
    @alert = Alert.new(alert_params)
    starts_at = alert_params['starts_at']
    ends_at = alert_params['ends_at']
    if starts_at.present?
      #@alert.starts_at = Date.strptime(starts_at, '%m/%d/%Y')
    end
    if ends_at.present?
      @alert.ends_at = Date.strptime(ends_at, '%Y-%m-%d').end_of_day
    end
    redirect_path = request.referrer || "/admin"
    @result = @alert.with_user(current_user).save
    respond_to do |format|
      if @result
        logger.info "New alert saved: #{@alert}"
        notice_message = "#{@alert.alert_type.humanize}: #{@alert.description} was successfully created for #{@alert.trail_systems.pluck(:trail_subsystem).to_sentence} #{@alert.trail_subtrails.pluck(:subtrail_name).to_sentence} #{@alert.pointsofinterests.pluck(:name).to_sentence}."
        format.html { redirect_to redirect_path , notice: notice_message }
        format.json { render action: 'show', status: :created, location: @alert }
        format.js {flash[:notice] = notice_message}
      else
        logger.info "Problem saving new alert: #{@alert}"
        format.html { render action: 'new' }
        format.json { render json: @alert.errors, status: :unprocessable_entity }
        format.js {}
      end
    end
    
  end

  # def create_multiple
  #   @alert = Alert.new(alert_params)


  #   respond_to do |format|
  #     if @alert.with_user(current_user).save
  #       format.html { redirect_to @alert, notice: 'Alert was successfully created.' }
  #       format.json { render action: 'show', status: :created, location: @alert }
  #     else
  #       format.html { render action: 'new' }
  #       format.json { render json: @alert.errors, status: :unprocessable_entity }
  #     end
  #   end
  # end

  # PATCH/PUT /alerts/1
  # PATCH/PUT /alerts/1.json
  def update
    authorize @alert
    logger.info "params = #{params}"
    logger.info "alert_params = #{alert_params}"
    @error_div_id = alert_params.delete(:div_id)
    starts_at = alert_params['starts_at']
    ends_at = alert_params['ends_at']
    if starts_at.present?
      #@alert.starts_at = Date.strptime(starts_at, '%m/%d/%Y')
      logger.info "update: alert_params['starts_at'] = #{alert_params['starts_at']} and updated @alert.starts_at = #{@alert.starts_at}"
    end
    if ends_at.present?
      #@alert.ends_at = Date.strptime(ends_at, '%m/%d/%Y')
      @alert.ends_at = Date.strptime(ends_at, '%Y-%m-%d').end_of_day
    end
    redirect_path = request.referrer || "/admin"
    #notice_message = "#{@alert.alert_type.humanize}: #{@alert.description} was successfully updated for #{@alert.trail_systems.pluck(:trail_subsystem).to_sentence} #{@alert.trail_subtrails.pluck(:subtrail_name).to_sentence} #{@alert.pointsofinterests.pluck(:name).to_sentence}."
    @result = @alert.with_user(current_user).update(alert_params)
    respond_to do |format|
      if @result
        notice_message = "#{@alert.alert_type.humanize}: #{@alert.description} was successfully updated for #{@alert.trail_systems.pluck(:trail_subsystem).to_sentence} #{@alert.trail_subtrails.pluck(:subtrail_name).to_sentence} #{@alert.pointsofinterests.pluck(:name).to_sentence}."

        format.html { redirect_to redirect_path , notice: notice_message }
        #format.html { redirect_to @alert, notice: 'Alert was successfully updated.' }
        format.json { head :no_content }
        format.js {flash[:notice] = notice_message}
      else
        format.html { render action: 'edit' }
        format.json { render json: @alert.errors, status: :unprocessable_entity }
        format.js {}
      end
    end
  end

  # DELETE /alerts/1
  # DELETE /alerts/1.json
  def destroy
    authorize @alert
    @alert.destroy
    redirect_path = request.referrer || "/admin"
    respond_to do |format|
      format.html { redirect_to redirect_path, notice: 'Alert was successfully deleted.' }
      format.json { head :no_content }
    end
  end

  def poi
    authorize Alert
    @act = current_user.level1? ? Pointsofinterest.has_parking.with_current_or_future_alerts.ransack(params[:q]) : Pointsofinterest.with_current_or_future_alerts.ransack(params[:q])
    query = ""
    @q = current_user.level1? ? Pointsofinterest.has_parking.no_current_or_future_alerts.ransack(params[:q]) : Pointsofinterest.no_current_or_future_alerts.ransack(params[:q])
    #@q.sorts = ['poi_info_id asc'] #if @q.sorts.empty?
    @pointsofinterests_active = @act.result.includes(:alerts)
    @pointsofinterests = @q.result.paginate(page: params[:page])
    @alert = Alert.new
    @alert.alertings.build
    @create_description = current_user.level1? ? "Add New Closure" : "Add New Alert"
  end

  def trail
    authorize Alert
    @act = TrailSystem.with_current_or_future_alerts.ransack(params[:q]) #.order(self.active_alerts_count)
    query = ""
    @q = TrailSystem.no_current_or_future_alerts.ransack(params[:q])
    #@q.sorts = ['poi_info_id asc'] #if @q.sorts.empty?
    @trails_active = @act.result.includes(:alerts, :trail_subtrails, :trails_infos)
    @trails = @q.result.includes(:trail_subtrails).paginate(page: params[:page])
    @alert = Alert.new
    @alert.alertings.build
    @create_description = current_user.level1? ? "Add New Closure" : "Add New Alert"
  end

  # GET alerts/history
  # PaperTrail change history
  def history
    authorize Alert
    respond_to do |format|
      format.html {
            @versions = PaperTrail::Version.where(item_type: 'Alert').includes(:item).order('created_at DESC').paginate(page: params[:page])
      }
      format.csv { 
        @versions = PaperTrail::Version.where(item_type: 'Alert').order('created_at DESC')
        fields = ['id', 'event', 'created_at', 'whodunnit', 'item_id', 'full_desc', 'pois', 'trails']
        output = CSV.generate do |csv|
          # Generate the headers
          csv << fields.map(&:titleize)

          # Write the results
          @versions.each do |version|
            csv << fields.map do |f|
              field_value = version[f]
              if f == 'whodunnit'
                if version[f].present? and User.exists?(version[f])
                  field_value = User.find(version[f]).email unless version[f].blank?
                end
              end
              field_value
            end
          end
        end
        send_data output, filename: "history-#{Date.today}.csv" 
      }
    end
  end

  def self.expire_alerts_json
    logger.info "starting Alert Controller self.expire_alerts_json"
    expire_page("alerts/list.json")
    expire_page("alerts.json")
  end

  def expire_alerts_json
    logger.info "starting Alert Controller expire_alerts_json"
    AlertsController.expire_alerts_json
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_alert
      @alert = Alert.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def alert_params
      params.require(:alert).permit(:div_id, :alert_id, :alert_type, :origin_type, :reason, :description, :link, :created_by, :starts_at, :ends_at, :geom, pointsofinterest_ids: [], trail_subtrail_ids: [], trail_system_ids: [], alertings_attributes: [:id, :alert_id, :alertable_id, :alertable_type, :created_by]
        )
    end
end
