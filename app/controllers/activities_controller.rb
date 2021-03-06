class ActivitiesController < ApplicationController
  before_action :set_activity, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!, except: [:index, :show]
  before_action :set_show_all_param
  #before_action :check_for_cancel, only: [:update]
  after_action :expire_cache, only: [:create, :destroy, :update, :upload]


  def upload
    if !current_user
      head 403
    end
    authorize Activity
    @confirmed = params[:confirmed] ? true : false
    #redirect_to trails_url, notice: "Please enter a source organization code for uploading activities data." if params[:source_id].empty?
    source_id = params[:source_id]
    #source_id = "FPDCC"
    #@source = Organization.find(source_id)
    parsed_activities = Activity.parse(params[:activities])
    if parsed_activities.nil?
      redirect_to activities_url, notice: "Unable to parse file #{params[:activities].original_filename}. Make sure it is a valid GeoJSON file or zipped shapefile."
      return
    end
    #source_activities = activity.where(source: @source)
    source_activities = Activity.all
    #@non_source_activitys = activity.where.not(source: @source)
    @removed_activities = []
    source_activities.each do |old_activity|
      removed_activity = Hash.new
      removed_activity[:activity] = old_activity
      if @confirmed
        removed_activity[:success] = old_activity.destroy
      else
        removed_activity[:success] = true
      end
      @removed_activities.push(removed_activity)
    end
    @added_activities = []
    parsed_activities.each do |new_activity|
      added_activity = Hash.new
      added_activity[:activity] = new_activity
      # if new_activity.activities_id.present?
      #   added_activity[:success] = true
        # if !new_activity.source.nil?
        #   added_activity[:message] = "activity organization #{new_activity.source.code} doesn't match user organization #{@source.code}"
        # else
        #   added_activity[:message] = "No activity source found or organization code in input does not match a known organization."
        # end
      if @confirmed
        if (new_activity.save)
          added_activity[:success] = true
        else
          added_activity[:success] = false
          added_activity[:message] = new_activity.errors.full_messages
        end
      else
        if (new_activity.valid?)
          added_activity[:success] = true
        else
          if new_activity.errors.full_messages == ["Name  has already been taken for this source"]
            added_activity[:success] = true
          else
            added_activity[:success] = false
            added_activity[:message] = new_activity.errors.full_messages
          end
        end
      end
      @added_activities.push(added_activity)
    end
  end

  def index
    respond_to do |format|
      format.html do 
        authenticate_user!
        authorize Activity
        if params[:all] == "true" || current_user.admin?
          @activities = Activity.order("activities_id").paginate(page: params[:page])
        else
          @activities = Activity.joins(:source).merge(Organization.where(id: current_user.organization)).order("activities_id")
        end
      end
      format.json do
        @activities = Activity.order("activities_id")
        entity_factory = ::RGeo::GeoJSON::EntityFactory.instance
        # if (params[:loc])
        #   @activities = sort_by_distance(@activities)
        # end
        features = []
        @activities.each do |activity|
          if activity.geom.present?
            json_attributes = create_json_attributes(activity)
            feature = entity_factory.feature(activity.geom, 
             activity.id, 
             json_attributes)
            features.push(feature)
          end
        end
        collection = entity_factory.feature_collection(features)
        my_geojson = RGeo::GeoJSON::encode(collection)
        render json: Oj.dump(my_geojson)
        cache_page(@response, "/activities.json")
      end
    end
  end

  def show
    respond_to do |format|   
      format.html do
        authenticate_user!
        authorize @activity
      end
      format.json do
        entity_factory = ::RGeo::GeoJSON::EntityFactory.instance
        json_attributes = create_json_attributes(@activity)
        feature = entity_factory.feature(@activity.geom, @activity.id, json_attributes)
        render json: RGeo::GeoJSON::encode(feature) 
      end
    end
  end

  # def new
  #   @activity = Activity.new
  #   respond_with(@activity)
  # end

  def edit
    authorize @activity
    # unless authorized?
    #   redirect_to activities_path, notice: 'Authorization failure.'
    # end
  end

  def create
    @activity = Activity.new(activity_params)
    authorize @activity
    @activity.save
  end

  def update
    authorize @activity
    respond_to do |format|
      if @activity.update(activity_params)
        format.html { redirect_to @activity, notice: 'Activity was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @activity.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    authorize @activity
    @activity.destroy
  end

  def default_url_options
    { all: @show_all }.merge(super)
  end

  def set_show_all_param
    @show_all = params[:all] if params[:all]
  end

  def create_json_attributes(activity)
    json_attributes = activity.attributes.except("id", "geom", "created_at", "updated_at", 'nameid', 'aname', 'parking_info_id')
    # if activity.source
    #   json_attributes["source"] = activity.source.code
    #   json_attributes["source_fullname"] = activity.source.full_name
    #   json_attributes["source_phone"] = activity.source.phone
    #   json_attributes["source_url"] = activity.source.url
    # end
    # if activity.steward
    #   json_attributes["steward"] = activity.steward.code
    #   json_attributes["steward_fullname"] = activity.steward.full_name
    #   json_attributes["steward_phone"] = activity.steward.phone
    #   json_attributes["steward_url"] = activity.steward.url
    # end
    #json_attributes["distance"] = activity.distance
    json_attributes["id"] = activity.activities_id
    json_attributes["name"] = activity.name
    json_attributes
  end

  def expire_cache
    ActionController::Base::expire_page("/activities.json")
    ActionController::Base::expire_page("/activities.json.gz")
  end

  private
    

    def set_activity
      @activity = Activity.find(params[:id])
    end

    def activity_params
      #params.require(:activity).permit(:activities_id, :nameid, :atype, :aname, :poi_info_id, :trail_info_id, :parking_info_id, :geom)
      params.require(:activity).permit(Activity.column_names - ["created_at", "updated_at"])

    end
end
