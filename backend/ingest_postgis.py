import os
import sys
sys.path.insert(0, os.path.dirname(__file__))

from app.services.document_loader import DocumentLoader
from app.services.database import db_service
from tqdm import tqdm

def ingest_shapefiles_to_postgis():
    """Import semua shapefile ke PostGIS gis_layers table"""
    
    shp_files = [f for f in DocumentLoader.list_local_files() if f['type'] == 'shp']
    print(f"Found {len(shp_files)} shapefiles")
    
    total = 0
    for f in shp_files:
        file_path = os.path.join(DocumentLoader.DATA_FOLDER, f['relative_path'])
        print(f"\nProcessing: {f['name']} ({f['size_mb']} MB)")
        
        try:
            features = DocumentLoader.load_shapefile_for_postgis(file_path, max_features=500)
            print(f"  Loaded {len(features)} features")
            
            count = 0
            for feat in tqdm(features, desc=f"  Inserting {f['name']}"):
                try:
                    db_service.insert_gis_layer(
                        name=feat.get('name', f['name']),
                        layer_type=feat.get('layer_type', 'pertanian'),
                        geom_wkt=feat['geom_wkt'],
                        properties=feat.get('properties', {})
                    )
                    count += 1
                except Exception as e:
                    print(f"  Error inserting feature: {e}")
            
            print(f"  Inserted: {count}/{len(features)}")
            total += count
        except Exception as e:
            print(f"  Error loading {f['name']}: {e}")
    
    print(f"\nTotal inserted: {total}")
    return total

if __name__ == '__main__':
    ingest_shapefiles_to_postgis()
