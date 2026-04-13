from pydantic import BaseModel
from datetime import datetime
from typing import Optional, Literal
from uuid import UUID

CategoryType = Literal['Nutrition', 'Exercise', 'Health Tips', 'Ethiopian Food']

class EducationBase(BaseModel):
    title: str
    title_amharic: Optional[str] = None
    content: str
    content_amharic: Optional[str] = None
    image_url: Optional[str] = None
    category: Optional[CategoryType] = None

class EducationCreate(EducationBase):
    """Admin payload to create an article."""
    pass

class EducationUpdate(BaseModel):
    """Admin payload to update an article."""
    title: Optional[str] = None
    title_amharic: Optional[str] = None
    content: Optional[str] = None
    content_amharic: Optional[str] = None
    image_url: Optional[str] = None
    category: Optional[CategoryType] = None

class EducationResponse(EducationBase):
    """Public response for articles."""
    id: UUID
    created_at: datetime
    updated_at: datetime