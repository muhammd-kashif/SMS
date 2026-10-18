import csv
import io
from datetime import date
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.database import get_db
from app.models.attendance import Attendance
from app.models.academic import Leave
from app.models.exam import Exam
from app.models.fee import FeeItem, Payment
from app.models.student import Student
from app.models.user import User

router = APIRouter(tags=["Reports"])


@router.get("/reports")
def get_reports(
    type: str = Query("students"),
    from_date: Optional[str] = Query(None, alias="from"),
    to_date: Optional[str] = Query(None, alias="to"),
    format: Optional[str] = Query("json"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = []
    headers = []

    if type == "students":
        students = db.query(Student).all()
        headers = ["ID", "Name", "Roll No", "Class", "Section", "Father Name", "Phone", "Status"]
        for s in students:
            rows.append({
                "ID": s.student_code,
                "Name": s.user.name if s.user else "",
                "Roll No": s.roll_number,
                "Class": s.school_class.name if s.school_class else "",
                "Section": s.section.name if s.section else "",
                "Father Name": s.father_name or "",
                "Phone": s.phone or "",
                "Status": s.status,
            })

    elif type == "attendance":
        q = db.query(Attendance)
        if from_date:
            q = q.filter(Attendance.attendance_date >= from_date)
        if to_date:
            q = q.filter(Attendance.attendance_date <= to_date)
        records = q.order_by(Attendance.attendance_date.desc()).limit(500).all()
        headers = ["Date", "Type", "Person ID", "Status", "Check In", "Method"]
        for r in records:
            rows.append({
                "Date": r.attendance_date.isoformat(),
                "Type": r.person_type.capitalize(),
                "Person ID": r.person_id,
                "Status": r.status.capitalize(),
                "Check In": str(r.check_in_time) if r.check_in_time else "",
                "Method": r.verification_method or "Manual",
            })

    elif type == "fees":
        fees = db.query(FeeItem).limit(500).all()
        headers = ["Fee Title", "Student", "Amount", "Paid", "Pending", "Due Date", "Status"]
        for f in fees:
            s_name = f.student.user.name if (f.student and f.student.user) else ""
            rows.append({
                "Fee Title": f.title,
                "Student": s_name,
                "Amount": float(f.amount),
                "Paid": float(f.paid_amount or 0),
                "Pending": f.pending_amount,
                "Due Date": f.due_date.isoformat() if f.due_date else "",
                "Status": f.status.capitalize(),
            })

    elif type == "payments":
        q = db.query(Payment).filter(Payment.status == "posted")
        if from_date:
            q = q.filter(Payment.paid_at >= from_date)
        if to_date:
            q = q.filter(Payment.paid_at <= to_date)
        payments = q.order_by(Payment.id.desc()).limit(500).all()
        headers = ["Receipt No", "Student", "Amount", "Method", "Date"]
        for p in payments:
            s_name = p.student.user.name if (p.student and p.student.user) else ""
            rows.append({
                "Receipt No": p.receipt_no,
                "Student": s_name,
                "Amount": float(p.amount),
                "Method": p.method.capitalize(),
                "Date": p.paid_at.isoformat() if p.paid_at else "",
            })

    elif type == "defaulters":
        today = date.today()
        fees = db.query(FeeItem).filter(FeeItem.due_date < today, FeeItem.status.in_(["pending", "partial"])).all()
        headers = ["Student Code", "Student Name", "Class", "Overdue Fee", "Pending Amount", "Due Date"]
        for f in fees:
            if f.pending_amount > 0 and f.student:
                rows.append({
                    "Student Code": f.student.student_code,
                    "Student Name": f.student.user.name if f.student.user else "",
                    "Class": f.student.school_class.name if f.student.school_class else "",
                    "Overdue Fee": f.title,
                    "Pending Amount": f.pending_amount,
                    "Due Date": f.due_date.isoformat() if f.due_date else "",
                })

    elif type == "exams":
        exams = db.query(Exam).order_by(Exam.start_date.desc()).all()
        headers = ["Exam Name", "Type", "Class", "Start Date", "End Date", "Published"]
        for ex in exams:
            rows.append({
                "Exam Name": ex.name,
                "Type": ex.exam_type,
                "Class": ex.school_class.name if ex.school_class else "",
                "Start Date": ex.start_date.isoformat() if ex.start_date else "",
                "End Date": ex.end_date.isoformat() if ex.end_date else "",
                "Published": "Yes" if ex.published else "No",
            })

    elif type == "leaves":
        leaves = db.query(Leave).order_by(Leave.id.desc()).limit(500).all()
        headers = ["Person Type", "Person ID", "Leave Type", "From", "To", "Days", "Status"]
        for lv in leaves:
            rows.append({
                "Person Type": lv.person_type.capitalize(),
                "Person ID": lv.person_id,
                "Leave Type": lv.leave_type,
                "From": lv.start_date.isoformat() if lv.start_date else "",
                "To": lv.end_date.isoformat() if lv.end_date else "",
                "Days": lv.days,
                "Status": lv.status.capitalize(),
            })

    if format == "csv":
        output = io.StringIO()
        writer = csv.DictWriter(output, fieldnames=headers)
        writer.writeheader()
        writer.writerows(rows)
        return Response(content=output.getvalue(), media_type="text/csv", headers={"Content-Disposition": f"attachment; filename={type}_report.csv"})

    if format == "pdf":
        from reportlab.lib.pagesizes import letter
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
        from reportlab.lib.styles import getSampleStyleSheet
        from reportlab.lib import colors

        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=letter)
        styles = getSampleStyleSheet()
        elements = [Paragraph(f"<b>{type.capitalize()} Report</b>", styles["Title"]), Spacer(1, 12)]

        if rows:
            data_matrix = [[h for h in headers]]
            for r in rows:
                data_matrix.append([str(r.get(h, "")) for h in headers])
            t = Table(data_matrix)
            t.setStyle(TableStyle([
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1e293b")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.whitesmoke),
                ("ALIGN", (0, 0), (-1, -1), "LEFT"),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("BOTTOMPADDING", (0, 0), (-1, 0), 8),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#cbd5e1")),
            ]))
            elements.append(t)
        else:
            elements.append(Paragraph("No records found.", styles["Normal"]))

        doc.build(elements)
        buffer.seek(0)
        return Response(content=buffer.getvalue(), media_type="application/pdf", headers={"Content-Disposition": f"inline; filename={type}_report.pdf"})

    return {"rows": rows}
