function [] = arcgisrisk(coords,ids,info,ishole,filename)
%ARCGISRISK outputs the results of risk.m (to be posted later)into the 
%ArcGIS environment.
%
%INPUTS
%-coords   -- 1xN cell array, each entry is an Mx2 matrix containing
%             coordinates corresponding to the outline of a risk polygon
%-ids      -- 1xN vector specifying the numerical risk classification of 
%             each polygon (1=severe, 2=moderate, etc.)
%-info     -- Nx3 matrix, first two columns specify the centroid of the nth
%             polygon (lat,long). third column specifies the area of each
%             polygon
%-ishole   -- Nx2 matrix, first column contains a binary value, 1 indicates
%             the polygon is a hole (inside of another), and the second
%             column identifies which polygon contains that hole
%-filename -- a string specifying the filename of the output
%
%OUTPUTS
%none, but generates corresponding .shp and .dbx files
%NB: the user must also generate a .prj file (via ArcGIS) to indicate the
%projection to be used
%
%
%In order to utilize Matlab's shapewrite function, need to create a struct
%with the following specifications (for N polygons of a certain type)
%Nx1 struct array with fields
%Geometry      -- 1xN cell array containing geometry information
%BoundingBox   -- 1xN cell array, each entry contains a 2x2 matrix
%                 specifying coordinates for a bounding box around the
%                 polygon in the format
%                 [minlongitude minlatitude;maxlongitude maxlatitude]
%X             -- 1xN cell array, each entry contains a 1xM vector
%                 specifying clockwise longitudinal coordinates for the
%                 outline of a polygon. The start/end point is repeated,
%                 and each vector ends in a NaN entry. To specify interior
%                 holes, after the NaN delimeter, list coordinates in
%                 counterclockwise order and end with another NaN delimeter
%Y             -- same format as X, but for the latitude portion of
%                 coordinate pairs
%Id            -- 1xN cell array, each entry is a string specifying an
%                 identification code for each polygon
%Arbitrary Fields


%count # of features for each risk type (excluding holes)
numfeats=hist(ids.*~ishole(:,1)',max(ids)+1);
numfeats=numfeats(2:end);

%count # of total features (including holes)
allfeats=hist(ids,max(ids));

%create two structs (and shapefiles) for each risk type, corresponding to
%polygons to be displayed and their 'placemarks'
itercounter=1;
for i=max(ids):-1:1
    %assume three risk classes
    haznames={'Severe Risk Sink' 'Moderate Risk Sink' 'Slight Risk Sink'};
    
    %instantiate polygon variables
    geometry=cell(1,numfeats(i));
    boundbox=cell(1,numfeats(i));
    lat=cell(1,numfeats(i));
    long=cell(1,numfeats(i));
    names=cell(1,numfeats(i));
    centroids=cell(1,numfeats(i));
    areas=cell(1,numfeats(i));
    
    %instantiate point variables
    ptgeometry=cell(1,numfeats(i));
    ptlat=cell(1,numfeats(i));
    ptlong=cell(1,numfeats(i));
    ptnames=cell(1,numfeats(i));
    ptcentroids=cell(1,numfeats(i));
    ptareas=cell(1,numfeats(i));
    
    datcounter=1;
    %fill cells for each polygon
    for j=1:allfeats(i)
        if ~ishole(itercounter,1) %ensure this is the outline of a polygon and not a hole
            %get current coordinate set
            tempcoords=coords{itercounter};
            templat=tempcoords(:,1);
            templong=tempcoords(:,2);
            
            %ensure proper orientation of coordinates (clockwise for outer 
            %def, counter-clockwise for interior holes)
            if ~ispolycw(templong,templat)
                [templong templat]=poly2cw(templong,templat);
            end
            
            %check if current polygon contains holes
            holes=find(ishole(:,2)==itercounter);
            
            if ~isempty(holes)
                %orient holes appropriately and affix coordinates
                for k=1:length(holes)
                    holecoords=coords{holes(k)};
                    holelat=holecoords(:,1);
                    holelong=holecoords(:,2);
                    %orient coordinates
                    if ispolycw(holelong,holelat)
                        [holelong holelat]=poly2ccw(holelong,holelat);
                    end
                    %affix to containing coordinates
                    templat=[templat NaN holelat];
                    templong=[templong NaN holelong];
                end
            end
            
            %enter polygon data
            geometry{datcounter}='Polygon';
            boundbox{datcounter}=[min(templong) min(templat);max(templong) max(templat)];
            lat{datcounter}=[templat' NaN];
            long{datcounter}=[templong' NaN];
            names{datcounter}=sprintf('%s #%i',haznames{i},j);
            centroids{datcounter}=sprintf('Centroid of area: %.4f,%.4f',info(itercounter,1:2));
            areas{datcounter}=sprintf('%.1f square meters',info(itercounter,3));
            
            %enter 'placemark' data (simply use a point at each centroid)
            ptgeometry{datcounter}='Point';
            ptlat{datcounter}=info(itercounter,1);
            ptlong{datcounter}=info(itercounter,2);
            ptnames{datcounter}=sprintf('%s #%i',haznames{i},j);
            ptcentroids{datcounter}=sprintf('Centroid of area: %.4f,%.4f',info(itercounter,1:2));
            ptareas{datcounter}=sprintf('%.1f square meters',info(itercounter,3));
            
            %increment datcounter
            datcounter=datcounter+1;
            
        end
        %increment itercounter
        itercounter=itercounter+1;
    end
    
    %create structs
    data=struct('Geometry',geometry,...
        'BoundingBox',boundbox,...
        'X',long,...
        'Y',lat,...
        'Id',names,...
        'Centroid',centroids,...
        'Area',areas);
    
    ptdata=struct('Geometry',ptgeometry,...
        'X',ptlong,...
        'Y',ptlat,...
        'Id',ptnames,...
        'Centroid',ptcentroids,...
        'Area',ptareas);
    
    %write data to an appropriately named shapefile
    shapewrite(data,[filename ' ' haznames{i}]);
    shapewrite(ptdata,[filename ' points ' haznames{i}]);
    
end

end