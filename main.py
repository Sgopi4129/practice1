from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from sqlalchemy import create_engine, Column, Integer, String, Sequence
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import SQLAlchemyError
from typing import List

# Database URL: SQLite in a local file (`courses.db`)
DATABASE_URL = "sqlite:///./courses.db"

# FastAPI app
app = FastAPI()

# SQLAlchemy setup
Base = declarative_base()

# Define the SoftwareCourse model
class SoftwareCourse(Base):
    __tablename__ = "courses"
    id = Column(Integer, Sequence('course_id_seq'), primary_key=True, autoincrement=True)
    name = Column(String, nullable=False)
    description = Column(String, nullable=False)
    duration = Column(String, nullable=False)

# Database engine and session
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create the database tables if they don't exist
Base.metadata.create_all(bind=engine)

# Request model for adding a course
class CourseRequest(BaseModel):
    name: str
    description: str
    duration: str

# Response model for retrieving a course
class CourseResponse(BaseModel):
    id: int
    name: str
    description: str
    duration: str

# Utility function to get a new database session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# POST endpoint to create a new course
@app.post("/courses/", response_model=CourseResponse)
def create_course(course: CourseRequest, db: Session = next(get_db())):
    try:
        new_course = SoftwareCourse(
            name=course.name,
            description=course.description,
            duration=course.duration
        )
        db.add(new_course)
        db.commit()
        db.refresh(new_course)
        return new_course
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to create course")

# GET endpoint to get all courses
@app.get("/courses/", response_model=List[CourseResponse])
def get_courses(db: Session = next(get_db())):
    try:
        courses = db.query(SoftwareCourse).all()
        return courses
    except SQLAlchemyError:
        raise HTTPException(status_code=500, detail="Failed to retrieve courses")

# To start the FastAPI server, run: uvicorn main:app --reload
