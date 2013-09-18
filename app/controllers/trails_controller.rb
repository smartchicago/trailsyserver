class TrailsController < ApplicationController
  before_action :set_trail, only: [:show, :edit, :update, :destroy]

  before_action :authenticate_user!, except: [:index]
  
  # GET /trails
  # GET /trails.json
  def index    
    respond_to do |format|
      format.html do
        authenticate_user!
        if params[:all] == "true" || current_user.admin?
          @trails = Trail.all   
        else
          @trails = Trail.where(source: current_user.organization)
        end
      end
      format.json do
        @trails = Trail.all
        entity_factory = ::RGeo::GeoJSON::EntityFactory.instance
        features = []
        @trails.each do |trail|
          # taking a trip to Null Island, because RGeo::GeoJSON chokes on empty geometry here
          filtered_attributes = trail.attributes.clone.except!("created_at", "updated_at")
          feature = entity_factory.feature(RGeo::Geographic.spherical_factory.point(0,0), trail.id, filtered_attributes)
          features.push(feature)
        end
        collection = entity_factory.feature_collection(features)
        my_geojson = RGeo::GeoJSON::encode(collection)
        render json: Oj.dump(my_geojson)
      end
    end
  end

  # GET /trails/1
  # GET /trails/1.json
  def show
    respond_to do |format|
      format.html
      format.json do
        entity_factory = ::RGeo::GeoJSON::EntityFactory.instance
        feature = entity_factory.feature(RGeo::Geographic.spherical_factory.point(0,0), @trail.id, @trail.attributes.except("geom", "wkt"))
        render json: RGeo::GeoJSON::encode(feature)
      end
    end
  end

  # # GET /trails/new
  # def new
  #   @trail = Trail.new
  # end

  # GET /trails/1/edit
  def edit
  end

  # POST /trails
  # POST /trails.json
  def create
    @trail = Trail.new(trail_params)

    respond_to do |format|
      if @trail.save
        format.html { redirect_to @trail, notice: 'Trail was successfully created.' }
        format.json { render action: 'show', status: :created, location: @trail }
      else
        format.html { render action: 'new' }
        format.json { render json: @trail.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /trails/1
  # PATCH/PUT /trails/1.json
  def update
    respond_to do |format|
      if @trail.update(trail_params)
        format.html { redirect_to @trail, notice: 'Trail was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @trail.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /trails/1
  # DELETE /trails/1.json
  def destroy

    respond_to do |format|
      if (@trail.source == current_user.organization || current_user.admin?) && @trail.destroy
        format.html { redirect_to trails_url, notice: "Trail '" + @trail.name + "' was successfully deleted." }
        format.json { render :json => { head: no_content }, status: :ok }
      else
        format.html { redirect_to trails_url, notice: "Trail '" + @trail.name + "' was not deleted." }
        format.json { render :json => { head: no_content }, status: :unprocessable_entity }
      end
    end
  end

  # POST /trails
  def upload
    redirect_to trails_url, notice: "Please enter a source organization code for uploading trail data." if params[:source].empty?
    parsed_trails = Trail.parse(params[:trails])
    if parsed_trails.nil?
      redirect_to trails_url, notice: "Unable to parse file #{params[:trails].original_filename}. Make sure it is a valid CSV file."
    end
    source_trails = Trail.source_trails(parsed_trails, current_user.organization || params[:source])
    @non_source_trails = Trail.non_source_trails(parsed_trails, current_user.organization || params[:source])
    if source_trails
      existing_org_trails = Trail.where(source: current_user.organization)
      @removed_trails = []
      existing_org_trails.each do |old_trail|
        removed_trail = Hash.new
        removed_trail[:trail] = old_trail
        removed_trail[:success] = old_trail.destroy
        @removed_trails.push(removed_trail)
      end
      @added_trails = []
      source_trails.each do |new_trail|
        added_trail = Hash.new
        added_trail[:trail] = new_trail
        added_trail[:success] = new_trail.save
        @added_trails.push(added_trail)
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_trail
      trail = Trail.find(params[:id])
      if params[:all] == "true" || trail.source == current_user.organization || current_user.admin?
        @trail = trail
      else
        # this should do something smarter
        head 403
      end
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def trail_params
      params.require(:trail).permit(:name, :opdmd_access, :source, :steward, :length, :equestrian, :dogs, :roadbike, :description, :hike_time, :print_map_url, :surface)
    end
end
