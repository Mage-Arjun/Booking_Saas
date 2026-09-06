from fastapi import Query
from pydantic import BaseModel


class PaginationParams:
    def __init__(
        self,
        skip: int = Query(0, ge=0),
        limit: int = Query(20, ge=1, le=100),
    ):
        self.skip = skip
        self.limit = limit


class PaginatedResponse[T](BaseModel):
    total: int
    items: list[T]
    skip: int
    limit: int
