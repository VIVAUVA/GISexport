function [] = gearthrisk(coords,posscolors,ids,info,ishole,filename)
%GEARTHRISK creates a kml file which displays calculated risk components in
%Google Earth. 
%
%INPUTS
%-coords     -- 1xN cell array, each entry is an Mx2 matrix containing
%               coordinates corresponding to the outline of a risk polygon
%-posscolors -- Mx3 matrix, each row contains the desired rgb values(1-255)
%               for each risk class
%-ids        -- 1xN vector specifying the numerical risk classification of 
%               each polygon (1=severe, 2=moderate, etc.)
%-info       -- Nx3 matrix, first two columns specify the centroid of the
%               nth polygon (lat,long). third column specifies the area of
%               each polygon
%-ishole     -- Nx2 matrix, first column contains a binary value, 1 indicates
%               the polygon is a hole (inside of another), and the second
%               column identifies which polygon contains that hole
%-filename   -- a string specifying the filename of the output
%
%OUTPUTS
%generates a corresponding kml file
%


%kml header
xml=['<?xml version="1.0" encoding="UTF-8"?>',10,...
    '<kml xmlns="http://earth.google.com/kml/2.1"',10,...
    'xmlns:gx="http://www.google.com/kml/ext/2.2">',10,...
    '<Document>',10,...
    '<name>',10,sprintf('%s.kml',filename),10,'</name>',10];

%specify kml styles for location markers and polygons -- includes highlight
%functionality
%load png templates (to be used as base for markers)
[template map alpha]=imread('sev.png');
%rewrite red pixels only (from arbitrarily marked template)
towrite=template(:,:,1)==255&template(:,:,2)==0;
[invtemplate map alpha]=imread('sevinv.png'); %alpha is the same here
invtowrite=invtemplate(:,:,1)==255&invtemplate(:,:,2)==0;

%note: kml colors are represented
%  00-FF  00-FF  00-FF  00-FF   
%  aplha    b      g      r

for i=1:length(posscolors)
    %write separate pngs for each risk color
    col=posscolors(i,:); %current color (rgb)
    %replace pixels to be written with new risk color
    newpng=double(template).*repmat(~towrite,[1 1 3])+...
        cat(3,towrite.*col(1),towrite.*col(2),towrite.*col(3));
    %do the same for the corresponding highlight png
    newinvpng=double(invtemplate).*repmat(~invtowrite,[1 1 3])+...
        cat(3,invtowrite.*col(1),invtowrite.*col(2),invtowrite.*col(3));
    imwrite(newpng,sprintf('sinkcol%i.png',i),'png','alpha',alpha);
    imwrite(newinvpng,sprintf('invsinkcol%i.png',i),'png','alpha',alpha);
    
    %translate polygon colors to kml hex (use 50% transparency)
    col=round(255.*posscolors(i,3:-1:1));
    col=dec2hex(col);
    col=sprintf('80%s%s%s',col(1,:),col(2,:),col(3,:));
    
    %create styles
    tempxml=[sprintf('<Style id="sinkcol%i">',i),10,...
        '<LineStyle>',10,...
        '<color>','00000000','</color>',10,...
        '<width>1</width>',10,...
        '</LineStyle>',10,...
        '<PolyStyle>',10,...
        '<color>',col,'</color>',10,...
        '</PolyStyle>',10,...
        '<IconStyle>',10,...
        sprintf('<Icon><href>sinkcol%i.png</href></Icon>',i),10,...
        '</IconStyle>',10,...
        '</Style>',10,...
        sprintf('<Style id="invsinkcol%i">',i),10,...
        '<LineStyle>',10,...
        '<color>','00000000','</color>',10,...
        '<width>1</width>',10,...
        '</LineStyle>',10,...
        '<PolyStyle>',10,...
        '<color>',col,'</color>',10,...
        '</PolyStyle>',10,...
        '<IconStyle>',10,...
        sprintf('<Icon><href>invsinkcol%i.png</href></Icon>',i),10,...
        '</IconStyle>',10,...
        '</Style>',10,...
        sprintf('<StyleMap id="sinkcol%imap">',i),10,...
        '<Pair>',10,...
        '<key>normal</key>',10,...
        sprintf('<styleUrl>#sinkcol%i</styleUrl>',i),10,...
        '</Pair>',10,...
        '<Pair>',10,...
        '<key>highlight</key>',10,...
        sprintf('<styleUrl>#invsinkcol%i</styleUrl>',i),10,...
        '</Pair>',10,...
        '</StyleMap>',10];
    xml=[xml tempxml];
end



%create polygons with corresponding placemarks
%assume 3 hazard classes here
haznames={'Severe Risk Sink' 'Moderate Risk Sink' 'Slight Risk Sink'};
foldertrack=0;
for i=1:length(coords)
    %check if the current polygon is a hole within another polygon
    if ishole(i,1)==0
        tempcoords=coords{i};
        tempcoords=[tempcoords(:,2) tempcoords(:,1)]';
        tempcoords=tempcoords(:)';
        
        %check if current polygon contains holes
        holes=find(ishole(:,2)==i);
        
        %group similar-risk polygons into the same Google Earth folder
        if ids(i)~=foldertrack && foldertrack==0
            xml=[xml '<Folder>',10,...
                '<name>',haznames{ids(i)},'s','</name>',10,...
                '<visibility>0</visibility>',10];
            foldertrack=ids(i);
            count=1;
        elseif ids(i)~=foldertrack && foldertrack~=0
            xml=[xml '</Folder>',10,'<Folder>',10,...
                '<name>',haznames{ids(i)},'s','</name>',10,...
                '<visibility>0</visibility>',10];
            foldertrack=ids(i);
            count=1;
        end
        
        %create polygon
        tempxml=['<Placemark>',10,...
            '<name></name>',10,...
            '<styleUrl>',sprintf('#sinkcol%imap',ids(i)),'</styleUrl>',10,...
            '<Polygon>',10,...
            '<extrude>0</extrude>',10,...
            '<altitudeMode>clampToGround</altitudeMode>',10,...
            '<outerBoundaryIs>',10,...
            '<LinearRing>',10,...
            '<coordinates>',10];
        %handle overlap of regions (favor severe risk polys)
        if ids(i)==1
            tempxml=[tempxml sprintf('%f,%f,7 ',tempcoords),10];
        elseif ids(i)==2
            tempxml=[tempxml sprintf('%f,%f,6 ',tempcoords),10];
        else
            tempxml=[tempxml sprintf('%f,%f,5 ',tempcoords),10];
        end
        tempxml=[tempxml '</coordinates>',10,...
            '</LinearRing>',10,...
            '</outerBoundaryIs>',10];
        
        %handle holes
        if ~isempty(holes)
            %orient holes appropriately and affix coordinates
            for k=1:length(holes)
                holecoords=coords{holes(k)};
                holecoords=[holecoords(:,2) holecoords(:,1)]';
                holecoords=holecoords(:)';
                
                tempxml=[tempxml '<innerBoundaryIs>',10,...
                    '<LinearRing>',10,...
                    '<coordinates>',10];
                
                %handle overlap of regions (favor severe risk polys)
                if ids(i)==1
                    tempxml=[tempxml sprintf('%f,%f,7 ',holecoords),10];
                elseif ids(i)==2
                    tempxml=[tempxml sprintf('%f,%f,6 ',holecoords),10];
                else
                    tempxml=[tempxml sprintf('%f,%f,5 ',holecoords),10];
                end
                tempxml=[tempxml '</coordinates>',10,...
                    '</LinearRing>',10,...
                    '</innerBoundaryIs>',10];
            end
        end
        tempxml=[tempxml '</Polygon>',10,...
            '</Placemark>',10];
        xml=[xml tempxml];
        
        %create placemark balloon with appropriate information
        tempxml=['<Placemark>',10,...
            '<name></name>',10,...
            sprintf('<description><![CDATA[<h3>%s #%i</h3><br>',haznames{ids(i)},count),10,...
            sprintf('<dt>Size of Area:</dt><dd>%.2f square meters</dd>]]>',info(i,3)),10,...
            '</description>',10,...
            '<styleUrl>',sprintf('#sinkcol%imap',ids(i)),'</styleUrl>',10,...
            '<Point>',10,...
            '<extrude>1</extrude>',10,...
            '<altitudeMode>clampToGround</altitudeMode>',10,...
            sprintf('<coordinates>%f,%f,200</coordinates>',info(i,2),info(i,1)),10,...
            '</Point>',10,...
            '</Placemark>',10];
        xml=[xml tempxml];
        
        count=count+1;
    end
end
xml=[xml '</Folder>',10];

%kml footer
xml=[xml '</Document>',10,'</kml>'];

%write to file
file=fopen(sprintf('%s.kml',filename),'wt');
fprintf(file,'%s',xml);
fclose(file);

end