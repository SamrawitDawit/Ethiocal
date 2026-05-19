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

    def estimate(self, frame, yolo_results=None):
        print(f"[FoodVolumeEstimator.estimate] START - frame shape: {frame.shape}")
        try:
        # 1. Run YOLOv8 Segmentation (or use provided results)
            print(f"  1. Running YOLOv8 segmentation...")
            if yolo_results is not None:
                print(f"  Using provided YOLO results")
                yolo_results = yolo_results[0] if isinstance(yolo_results, list) else yolo_results
            else:
                yolo_results = self.yolo_model(frame, conf=0.15, task="segment")[0]
            print(f"  YOLOv8 complete, masks: {yolo_results.masks is not None}")

        # 2. Run Depth Anything V2
            print(f"  2. Running Depth Anything V2 inference...")
            depth_map = self.depth_model.infer_image(frame)
            print(f"  Depth map generated: shape={depth_map.shape}")

            # --- COMPUTE PLATE PIXEL COUNT ---
            # Estimate plate area by dilating combined food mask to find plate ring
            print(f"  3. Computing plate pixel count...")
            
            # Create a combined mask of all food items
            combined_food_mask = np.zeros_like(depth_map, dtype=np.uint8)
            if yolo_results.masks is not None:
                for mask in yolo_results.masks.data:
                    mask_np = mask.cpu().numpy()
                    mask_resized = cv2.resize(mask_np, (frame.shape[1], frame.shape[0]))
                    combined_food_mask = np.maximum(combined_food_mask, (mask_resized > 0.5).astype(np.uint8))
            
            # Dilate the combined food mask to get the plate ring area around all foods
            kernel = np.ones((30, 30), np.uint8)
            dilated_food = cv2.dilate(combined_food_mask, kernel, iterations=5)
            plate_mask = dilated_food - combined_food_mask
            plate_pixel_count = int(np.sum(plate_mask > 0))
            
            print(f"      Plate pixel count: {plate_pixel_count}")
            
            # --- GLOBAL PLATE BASELINE CALCULATION ---
            # Compute plate depth ONCE globally for the entire scene
            # This is critical because monocular depth maps are only meaningful relatively within the same scene
            print(f"  4. Computing global plate baseline...")
            
            # For inverse depth (smaller = closer), the plate is FARTHER
            # Use percentile instead of max for robustness against noise
            if len(depth_map[plate_mask > 0]) > 0:
                plate_depths = depth_map[plate_mask > 0]
                global_plate_baseline = np.percentile(plate_depths, 90)  # Use 90th percentile for robustness
                print(f"      Global plate baseline (90th percentile): {global_plate_baseline}")
            else:
                # Fallback: use 90th percentile of entire depth map
                global_plate_baseline = np.percentile(depth_map, 90)
                print(f"      Global plate baseline (90th percentile of full map): {global_plate_baseline}")

            processed_data = []

            if yolo_results.masks is not None:
                print(f"  5. Processing {len(yolo_results.boxes.data)} detections...")
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

                    # Resize mask to match original image dimensions
                    mask_np = mask.cpu().numpy()
                    mask_resized = cv2.resize(mask_np, (frame.shape[1], frame.shape[0]))

                    # Count pixels in the binary mask
                    mask_binary = (mask_resized > 0.5).astype(np.uint8)
                    mask_pixel_count = int(np.sum(mask_binary))

                    # Compute area ratio
                    if plate_pixel_count > 0:
                        area_ratio = mask_pixel_count / plate_pixel_count
                    else:
                        area_ratio = 0.0
                        print(f"      Warning: plate_pixel_count is 0")

                    # Compute relative depth features
                    food_depths = depth_map[mask_resized > 0]

                    # For inverse depth: Height = global_plate_baseline - food_depth (closer = smaller number)
                    raw_heights = global_plate_baseline - food_depths
                    raw_heights = np.maximum(raw_heights, 0)  # Remove negatives

                    # Remove tiny noise (threshold 0.15)
                    significant_heights = raw_heights[raw_heights > 0.15]

                    # Compute height statistics
                    if len(significant_heights) > 0:
                        mean_height = float(np.mean(significant_heights))
                        p75_height = float(np.percentile(significant_heights, 75))
                        max_height = float(np.max(significant_heights))
                    else:
                        # Fallback to zeros if too few significant pixels
                        mean_height = 0.0
                        p75_height = 0.0
                        max_height = 0.0
                        print(f"      Warning: Too few significant height pixels, using zeros")

                    # Compute mound score
                    mound_score = 0.7 * mean_height + 0.3 * p75_height
                    mound_score = float(np.clip(mound_score / 4.0, 0, 2))  # Normalize to 0-2 range

                    height_stats = {
                        "mean": mean_height,
                        "p75": p75_height,
                        "max": max_height,
                        "effective": mound_score
                    }

                    print(f"      Mask pixel count: {mask_pixel_count}")
                    print(f"      Area ratio: {area_ratio:.4f}")
                    print(f"      Height stats - mean: {mean_height:.2f}, p75: {p75_height:.2f}, max: {max_height:.2f}")
                    print(f"      Mound score: {mound_score:.2f}")

                    # STEP 5: FOOD-SPECIFIC ESTIMATION
                    food_type_lower = food_type.lower()
                    grams = None

                    # INJERA - Depth has very little influence
                    if "injera" in food_type_lower:
                        grams = 220 * area_ratio
                        grams = float(np.clip(grams, 30, 325))
                        print(f"      INJERA estimation: {grams:.1f}g (area_ratio={area_ratio:.4f})")

                    # SHIRO / MISIR / WAT - Use area + mound
                    elif any(x in food_type_lower for x in ["shiro", "misir", "wat", "wot", "alciha"]):
                        grams = 420 * area_ratio * (1 + mound_score * 0.6)
                        grams = float(np.clip(grams, 20, 400))
                        print(f"      SHIRO/MISIR/WAT estimation: {grams:.1f}g (area_ratio={area_ratio:.4f}, mound_score={mound_score:.2f})")

                    # GOMEN / SALAD - Lighter foods
                    elif any(x in food_type_lower for x in ["gomen", "selata", "fosoliya"]):
                        grams = 250 * area_ratio * (1 + mound_score * 0.3)
                        grams = float(np.clip(grams, 10, 250))
                        print(f"      GOMEN/SALAD estimation: {grams:.1f}g (area_ratio={area_ratio:.4f}, mound_score={mound_score:.2f})")

                    # KITFO / BOWL FOODS - Bowls explode area estimates
                    elif any(x in food_type_lower for x in ["kitfo", "bowl"]):
                        effective_area = np.sqrt(area_ratio)
                        grams = 500 * effective_area * (1 + mound_score * 0.4)
                        grams = float(np.clip(grams, 50, 450))
                        print(f"      KITFO/BOWL estimation: {grams:.1f}g (effective_area={effective_area:.4f}, mound_score={mound_score:.2f})")

                    # DEFAULT: Generic estimation for unknown foods
                    else:
                        grams = 300 * area_ratio * (1 + mound_score * 0.4)
                        grams = float(np.clip(grams, 20, 350))
                        print(f"      DEFAULT estimation: {grams:.1f}g (area_ratio={area_ratio:.4f}, mound_score={mound_score:.2f})")

                    processed_data.append({
                        "food_type": food_type,
                        "box": yolo_results.boxes.xyxy[i].tolist(),
                        "mask_pixel_count": mask_pixel_count,
                        "area_ratio": area_ratio,
                        "height_stats": height_stats,
                        "estimated_grams": grams,
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