import sys
import os
import cv2
import torch
import numpy as np
from ultralytics import YOLO

current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(current_dir, "Depth-Anything-V2"))
from depth_anything_v2.dpt import DepthAnythingV2

class FoodVolumeEstimator:
    def __init__(self):
        print(f"[FoodVolumeEstimator.__init__] START")

        # 1. Setup Device (GPU if available, else CPU)
        print(f"  1. Setting up device...")
        self.device = 'cuda' if torch.cuda.is_available() else 'cpu'
        print(f"  ✓ Device: {self.device}")

        # 2. Initialize YOLOv8
        print(f"  2. Loading YOLOv8 model...")
        from app.core.config import settings
        print(f"     YOLO_MODEL_PATH={settings.YOLO_MODEL_PATH}")
        try:
            self.yolo_model = YOLO(settings.YOLO_MODEL_PATH)
            print(f"  ✓ YOLOv8 model loaded")
        except Exception as e:
            print(f"  ✗ Failed to load YOLOv8: {e}")
            raise

        # 3. Initialize Depth Anything V2 (Base Config)
        # These features/channels are specific to the "Base" (vitb) model
        print(f"  3. Setting up Depth Anything V2 model config...")
        model_configs = {
            'vitb': {'encoder': 'vitb', 'features': 128, 'out_channels': [96, 192, 384, 768]}
        }
        print(f"     Model config: {model_configs['vitb']}")

        print(f"  4. Creating DepthAnythingV2 instance...")
        try:
            self.depth_model = DepthAnythingV2(**model_configs['vitb'])
            print(f"  DepthAnythingV2 instance created")
        except Exception as e:
            print(f"  Failed to create DepthAnythingV2: {e}")
            raise

        # Load the weights you downloaded
        print(f"  5. Loading depth model weights...")
        from app.core.config import settings
        checkpoint_path = settings.DEPTH_MODEL_PATH
        print(f"     Checkpoint path: {checkpoint_path}")

        try:
            import os
            if not os.path.exists(checkpoint_path):
                raise FileNotFoundError(f"Checkpoint file not found: {checkpoint_path}")
            print(f"     File exists: {os.path.getsize(checkpoint_path)} bytes")

            print(f"     Loading checkpoint with map_location={self.device}...")
            checkpoint = torch.load(checkpoint_path, map_location=self.device)
            print(f"     Checkpoint loaded, applying to model...")
            self.depth_model.load_state_dict(checkpoint)
            print(f"  Checkpoint loaded")
        except Exception as e:
            print(f"  Failed to load checkpoint: {type(e).__name__}: {e}")
            raise

        print(f"  6. Moving model to device and setting to eval mode...")
        self.depth_model.to(self.device).eval()
        print(f"   Model ready on {self.device}")
        print(f"[FoodVolumeEstimator.__init__] SUCCESS")

    def estimate(self, frame):
        print(f"[FoodVolumeEstimator.estimate] START - frame shape: {frame.shape}")
        try:
        # 1. Run YOLOv8 Segmentation
            print(f"  1. Running YOLOv8 segmentation...")
            yolo_results = self.yolo_model(frame, conf=0.25)[0]
            print(f"  YOLOv8 complete, masks: {yolo_results.masks is not None}")

        # 2. Run Depth Anything V2
            print(f"  2. Running Depth Anything V2 inference...")
            depth_map = self.depth_model.infer_image(frame)
            print(f"  Depth map generated: shape={depth_map.shape}")

            # --- GLOBAL PLATE BASELINE CALCULATION ---
            # Compute plate depth ONCE globally for the entire scene
            # This is critical because monocular depth maps are only meaningful relatively within the same scene
            print(f"  3. Computing global plate baseline...")
            
            # Create a combined mask of all food items
            combined_food_mask = np.zeros_like(depth_map, dtype=np.uint8)
            if yolo_results.masks is not None:
                for mask in yolo_results.masks.data:
                    mask_np = mask.cpu().numpy()
                    mask_resized = cv2.resize(mask_np, (frame.shape[1], frame.shape[0]))
                    combined_food_mask = np.maximum(combined_food_mask, (mask_resized > 0.5).astype(np.uint8))
            
            # Dilate the combined food mask to get the plate ring area around all foods
            kernel = np.ones((15, 15), np.uint8)
            dilated_food = cv2.dilate(combined_food_mask, kernel, iterations=3)
            plate_ring = dilated_food - combined_food_mask
            
            # For inverse depth (smaller = closer), the plate is FARTHER
            # Use percentile instead of max for robustness against noise
            if len(depth_map[plate_ring > 0]) > 0:
                plate_depths = depth_map[plate_ring > 0]
                global_plate_baseline = np.percentile(plate_depths, 90)  # Use 90th percentile for robustness
                print(f"      Global plate baseline (90th percentile): {global_plate_baseline}")
            else:
                # Fallback: use 90th percentile of entire depth map
                global_plate_baseline = np.percentile(depth_map, 90)
                print(f"      Global plate baseline (90th percentile of full map): {global_plate_baseline}")

            processed_data = []

            if yolo_results.masks is not None:
                print(f"  4. Processing {len(yolo_results.boxes.data)} detections...")
                # Iterate through boxes to ensure correct mask-to-label association
                for i in range(len(yolo_results.boxes.data)):
                    food_type = yolo_results.names[int(yolo_results.boxes.cls[i])]
                    print(f"    Processing detection {i+1} (YOLO classified as: {food_type})...")
                    
                    # Get the corresponding mask for this detection
                    if i < len(yolo_results.masks.data):
                        mask = yolo_results.masks.data[i]
                    else:
                        print(f"      No mask available for detection {i+1}")
                        continue
                
                # Debug: Print mask info BEFORE resizing
                    mask_np = mask.cpu().numpy()
                    print(f"      BEFORE RESIZE - mask.shape: {mask_np.shape}")
                    print(f"      BEFORE RESIZE - np.unique(mask): {np.unique(mask_np)}")
                    print(f"      BEFORE RESIZE - mask.sum(): {mask_np.sum()}")
                
                # Resize mask to match original image dimensions
                    mask_resized = cv2.resize(mask_np, (frame.shape[1], frame.shape[0]))
                
                # Debug: Print mask info AFTER resizing
                    print(f"      AFTER RESIZE - mask.shape: {mask_resized.shape}")
                    print(f"      AFTER RESIZE - np.unique(mask): {np.unique(mask_resized)}")
                    print(f"      AFTER RESIZE - mask.sum(): {mask_resized.sum()}")

                # 2. Find heights of food pixels
                    food_depths = depth_map[mask_resized > 0]
                
                # For inverse depth: Height = global_plate_baseline - food_depth (closer = smaller number)
                # This gives positive height values
                    raw_heights = global_plate_baseline - food_depths
                    raw_heights = np.maximum(raw_heights, 0)  # Remove negatives
                
                # Get the maximum raw height for normalization
                    max_raw_height = np.max(raw_heights) if len(raw_heights) > 0 else 1.0
                    print(f"      Max raw height: {max_raw_height}")
                
                # Calculate total raw volume units by summing all pixel heights
                    # raw_heights is already extracted from the mask, so just sum it
                    total_raw_volume_units = float(np.sum(raw_heights))

                    # Count pixels in the binary mask for pixel area
                    mask_binary = (mask_resized > 0.5).astype(np.uint8)
                    pixel_area = int(np.sum(mask_binary))

                    print(f"      Mask resized shape: {mask_resized.shape}")
                    print(f"      Mask resized min/max: {mask_resized.min()}/{mask_resized.max()}")
                    print(f"      Mask resized unique values: {np.unique(mask_resized)[:10]}")
                    print(f"      Pixel area: {pixel_area}")
                    print(f"      Max raw height: {max_raw_height}")
                    print(f"      Total raw volume units: {total_raw_volume_units}")


                    processed_data.append({
                        "food_type": food_type,
                        "pixel_area": pixel_area,
                        "total_raw_volume_units": total_raw_volume_units,
                        "plate_baseline": float(global_plate_baseline),
                        "max_raw_height": float(max_raw_height)
                    })
            else:
                print(f"  No masks found in YOLOv8 results")

            print(f"  Processed {len(processed_data)} items")
            print(f"[FoodVolumeEstimator.estimate] SUCCESS")
            return processed_data, depth_map
        except Exception as e:
            print(f" Error in estimate: {type(e).__name__}: {e}")
            import traceback
            traceback.print_exc()
            raise