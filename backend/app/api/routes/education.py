import uuid
from fastapi import APIRouter, Depends, HTTPException, status, Query, UploadFile, File, Form
from typing import List, Optional
from uuid import UUID
from app.core.config import settings
from app.db.supabase import get_supabase_admin
from app.core.dependencies import get_current_user, get_current_admin
from app.schemas.education import EducationCreate, EducationUpdate, EducationResponse
from app.schemas.analytics import CountResponse

router = APIRouter()

@router.get("/", response_model=List[EducationResponse])
async def list_articles(
    category: str = Query(None, description="Filter by category"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    _user: dict = Depends(get_current_user)
):
    """Get all education and awareness articles."""
    supabase = get_supabase_admin()
    query = supabase.table("education_articles").select("*").order("created_at", desc=True)
    
    if category:
        query = query.eq("category", category)
        
    result = query.range(skip, skip + limit - 1).execute()
    return result.data

@router.get("/{article_id}", response_model=EducationResponse)
async def get_article_details(article_id: UUID, _user: dict = Depends(get_current_user)):
    """See details of a specific article."""
    supabase = get_supabase_admin()
    result = (
        supabase.table("education_articles")
        .select("*")
        .eq("id", str(article_id))
        .maybe_single()
        .execute()
    )
    
    if not result.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Article not found")
    
    return result.data

@router.get("/stats/count", response_model=CountResponse)
async def count_educational_content(_admin: dict = Depends(get_current_admin)):
    """Count the total number of educational articles (Admin only)."""
    supabase = get_supabase_admin()
    result = (
        supabase.table("education_articles")
        .select("*", count="exact")
        .limit(0)
        .execute()
    )
    return {"count": result.count or 0}

# --- Admin Operations ---

@router.post("/", response_model=EducationResponse, status_code=status.HTTP_201_CREATED) # Admin restriction removed
async def create_article(
    title: str = Form(...),
    content: str = Form(...),
    title_amharic: Optional[str] = Form(None),
    content_amharic: Optional[str] = Form(None),
    category: Optional[str] = Form(None),
    image: UploadFile = File(None),
    _user: dict = Depends(get_current_user)
):
    """Create a new article with an optional image upload."""
    supabase = get_supabase_admin()
    
    image_url = None
    if image:
        if image.content_type not in ("image/jpeg", "image/png", "image/webp"):
            raise HTTPException(status_code=400, detail="Invalid image type.")
        
        contents = await image.read()
        if len(contents) > 5 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Image too large.")
            
        ext = image.filename.rsplit(".", 1)[-1] if image.filename else "jpg"
        filename = f"articles/{uuid.uuid4()}.{ext}"
        
        supabase.storage.from_("education-images").upload(
            path=filename,
            file=contents,
            file_options={"content-type": image.content_type},
        )
        image_url = supabase.storage.from_("education-images").get_public_url(filename)

    article_data = {
        "title": title,
        "content": content,
        "title_amharic": title_amharic,
        "content_amharic": content_amharic,
        "category": category,
        "image_url": image_url
    }

    result = supabase.table("education_articles").insert(article_data).execute()
    
    if not result.data:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Failed to create article")
    
    return result.data[0]

@router.put("/{article_id}", response_model=EducationResponse) # Admin restriction removed
async def update_article(
    article_id: UUID, 
    title: Optional[str] = Form(None),
    content: Optional[str] = Form(None),
    title_amharic: Optional[str] = Form(None),
    content_amharic: Optional[str] = Form(None),
    category: Optional[str] = Form(None),
    image: UploadFile = File(None),
    _user: dict = Depends(get_current_user)
):
    """Update an existing article, optionally replacing the image."""
    supabase = get_supabase_admin()
    
    update_data = {}
    if title is not None: update_data["title"] = title
    if content is not None: update_data["content"] = content
    if title_amharic is not None: update_data["title_amharic"] = title_amharic
    if content_amharic is not None: update_data["content_amharic"] = content_amharic
    if category is not None: update_data["category"] = category

    if image:
        if image.content_type not in ("image/jpeg", "image/png", "image/webp"):
            raise HTTPException(status_code=400, detail="Invalid image type.")
            
        contents = await image.read()
        if len(contents) > 5 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Image too large.")
            
        ext = image.filename.rsplit(".", 1)[-1] if image.filename else "jpg"
        filename = f"articles/{uuid.uuid4()}.{ext}"
        
        supabase.storage.from_("education-images").upload(
            path=filename,
            file=contents,
            file_options={"content-type": image.content_type},
        )
        update_data["image_url"] = supabase.storage.from_("education-images").get_public_url(filename)
    
    if not update_data:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No fields to update")
        
    result = supabase.table("education_articles").update(update_data).eq("id", str(article_id)).execute()
    
    if not result.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Article not found")
        
    return result.data[0]

@router.patch("/{article_id}", response_model=EducationResponse)
async def patch_article(
    article_id: UUID, 
    title: Optional[str] = Form(None),
    content: Optional[str] = Form(None),
    title_amharic: Optional[str] = Form(None),
    content_amharic: Optional[str] = Form(None),
    category: Optional[str] = Form(None),
    image: UploadFile = File(None),
    _user: dict = Depends(get_current_user)
):
    """Partially update an existing article with the same logic as the PUT request."""
    supabase = get_supabase_admin()
    
    update_data = {}
    if title is not None: update_data["title"] = title
    if content is not None: update_data["content"] = content
    if title_amharic is not None: update_data["title_amharic"] = title_amharic
    if content_amharic is not None: update_data["content_amharic"] = content_amharic
    if category is not None: update_data["category"] = category

    if image:
        if image.content_type not in ("image/jpeg", "image/png", "image/webp"):
            raise HTTPException(status_code=400, detail="Invalid image type.")
            
        contents = await image.read()
        if len(contents) > 5 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Image too large.")
            
        ext = image.filename.rsplit(".", 1)[-1] if image.filename else "jpg"
        filename = f"articles/{uuid.uuid4()}.{ext}"
        
        supabase.storage.from_("education-images").upload(
            path=filename,
            file=contents,
            file_options={"content-type": image.content_type},
        )
        update_data["image_url"] = supabase.storage.from_("education-images").get_public_url(filename)
    
    if not update_data:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No fields to update")
        
    result = (
        supabase.table("education_articles")
        .update(update_data)
        .eq("id", str(article_id))
        .execute()
    )
    
    if not result.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Article not found")
        
    return result.data[0]

@router.delete("/{article_id}", status_code=status.HTTP_204_NO_CONTENT) # Admin restriction removed
async def delete_article(article_id: UUID, _user: dict = Depends(get_current_user)):
    """Delete an article (Admin only)."""
    supabase = get_supabase_admin()
    
    # Check existence
    check = supabase.table("education_articles").select("id").eq("id", str(article_id)).maybe_single().execute()
    if not check.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Article not found")

    supabase.table("education_articles").delete().eq("id", str(article_id)).execute()
    return None
