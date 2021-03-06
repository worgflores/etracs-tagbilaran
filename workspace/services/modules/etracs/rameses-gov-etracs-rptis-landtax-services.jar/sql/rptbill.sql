[findOpenLedger]
SELECT 
	rl.objid,
	rl.lastyearpaid,
	rl.lastqtrpaid,
	rl.undercompromise,
	rl.faasid, 
	rl.tdno,
	rl.taxpayer_objid, 
	e.name AS taxpayer_name, 
	e.address_text AS taxpayer_address, 
	rl.owner_name,
	rl.administrator_name,
	rl.rputype,
	rl.fullpin,
	rl.totalareaha,
	rl.totalareaha * 10000 AS totalareasqm,
	rl.totalav,
	rl.taxable,
	b.name AS barangay,
	b.objid AS barangayid,
	rl.cadastrallotno,
	rl.barangayid,
	rl.classcode,
    rl.nextbilldate,
    case when m.objid is not null then m.parentid else null end as parentlguid,
    case when m.objid is not null then m.objid else d.parentid end as lguid
FROM rptledger rl 
	INNER JOIN barangay b ON rl.barangayid = b.objid 
	INNER JOIN entity e ON rl.taxpayer_objid = e.objid 
    left join municipality m on b.parentid = m.objid 
    left join district d  on b.parentid = d.objid 
WHERE rl.objid = $P{rptledgerid}
AND rl.state = 'APPROVED'
AND (
	( rl.lastyearpaid < $P{billtoyear} OR (rl.lastyearpaid = $P{billtoyear} AND rl.lastqtrpaid < $P{billtoqtr}))
	or 
	(exists(select * from rptledger_item where parentid = rl.objid))
)


[getBilledLedgers]
SELECT 
    rl.objid,
    rl.lastyearpaid,
    rl.lastqtrpaid,
    rl.tdno,
    rl.rputype,
    rl.fullpin,
    rl.totalareaha,
    rl.totalareaha * 10000 AS totalareasqm,
    rl.totalav,
    rl.owner_name, 
    b.name AS barangay,
    rl.cadastrallotno,
    rl.classcode
FROM rptledger rl 
  INNER JOIN barangay b ON rl.barangayid = b.objid 
  INNER JOIN entity e ON rl.taxpayer_objid = e.objid 
WHERE rl.objid IN (
    SELECT rl.objid 
    FROM rptledger rl 
    WHERE rl.taxpayer_objid = $P{taxpayerid} 
     and rl.objid like $P{rptledgerid}
     AND rl.state = 'APPROVED'
     AND rl.taxable = 1 
     and rl.totalav > 0 
     and rl.rputype like $P{rputype}
     and rl.barangayid like $P{barangayid}
     AND (rl.lastyearpaid < $P{billtoyear} 
          OR ( rl.lastyearpaid = $P{billtoyear} AND rl.lastqtrpaid < $P{billtoqtr})
     )

    UNION 

    SELECT rl.objid 
    FROM propertypayer pp
        inner join propertypayer_item ppi on pp.objid = ppi.parentid
        inner join rptledger rl on ppi.rptledger_objid = rl.objid 
    WHERE pp.taxpayer_objid = $P{taxpayerid}
    and rl.objid like $P{rptledgerid}
     AND rl.state = 'APPROVED'
     AND rl.taxable = 1 
     and rl.totalav > 0 
     and rl.rputype like $P{rputype}
     and rl.barangayid like $P{barangayid}
     AND (rl.lastyearpaid < $P{billtoyear} 
            OR ( rl.lastyearpaid = $P{billtoyear} AND rl.lastqtrpaid < $P{billtoqtr})
     )
)
and not exists(select * from faas_restriction where ledger_objid = rl.objid and state='ACTIVE')
ORDER BY rl.tdno  




[findLatestPayment]
select max(x.receiptdate) as receiptdate
from (
    select max(c.receiptdate) as receiptdate 
    from cashreceipt c
        inner join cashreceipt_rpt cr on c.objid = cr.objid 
        inner join rptpayment rp on c.objid = rp.receiptid 
        left join cashreceipt_void cv on c.objid = cv.receiptid
    where rp.refid = $P{objid}
    and $P{cy} >= rp.fromyear and $P{cy} <= rp.toyear 
    and cv.objid is null 

    union 

    select max(refdate) as receiptdate 
    from rptledger_credit cr 
    where cr.rptledgerid = $P{objid}
     and ((cr.fromyear = $P{cy} and cr.fromqtr = 1) 
                or (cr.toyear = $P{cy} and cr.toqtr >= 1)
                or ($P{cy} > cr.fromyear and $P{cy} < cr.toyear)
        )
)x


[getCurrentYearCredits]	
select x.* 
from (
    select c.receiptdate, min(cro.qtr) as fromqtr, max(cro.qtr) as toqtr
    from cashreceipt c 
    inner join rptpayment rp on c.objid = rp.receiptid 
    inner join rptpayment_item cro on rp.objid = cro.parentid
    left join cashreceipt_void cv on c.objid = cv.receiptid
    where rp.refid = $P{objid}
    and cro.year = $P{cy}
    and cv.objid is null 
    group by c.receiptdate, cro.year 

    union 

    select 
        rc.refdate as receiptdate, 
        case when $P{cy} = rc.fromyear then rc.fromqtr else 1 end as fromqtr,
        case when $P{cy} = rc.toyear then rc.toqtr else 4 end as toqtr
    from rptledger_credit rc
    where rc.rptledgerid = $P{objid}
    and $P{cy} >= rc.fromyear and $P{cy} <= rc.toyear 
)x 
order by x.fromqtr 


