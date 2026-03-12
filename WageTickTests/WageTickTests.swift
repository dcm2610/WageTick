//
//  WageTickTests.swift
//  WageTickTests
//
//  Created by Dan Morgan on 11/03/2026.
//

import Testing
import Foundation
@testable import WageTick

struct WageTickTests {

    @Test("Unpaid break deduction works correctly")
    func testUnpaidBreakDeduction() {
        // 8 hour shift at £15/hr with 30 min unpaid break
        // Total: 8 × £15 = £120
        // Unpaid break cost: 0.5 × £15 = £7.50
        // Net pay: £112.50
        
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(8 * 3600)  // 8 hours
        let shift = Shift(hourlyWage: 15, startTime: startTime, endTime: endTime, unpaidBreakDuration: 30 * 60)
        
        let totalPay = shift.totalShiftPay()
        let expected = Decimal(15) * Decimal(7.5)  // 7.5 paid hours
        
        #expect(totalPay == expected)
    }
    
    @Test("Earned so far as percentage of total shift pay")
    func testEarnedSoFarAsPercentage() {
        // 8 hour shift at £15/hr with 30 min unpaid break = £112.50 total
        // After 4 hours elapsed = 50% of shift = £56.25
        
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(8 * 3600)  // 8 hours
        let shift = Shift(hourlyWage: 15, startTime: startTime, endTime: endTime, unpaidBreakDuration: 30 * 60)
        
        let afterFourHours = startTime.addingTimeInterval(4 * 3600)
        let earned = shift.earnedSoFar(now: afterFourHours)
        
        let expected = Decimal(56.25)
        #expect(earned == expected)
    }
    
    @Test("No unpaid break = linear earnings")
    func testNoUnpaidBreak() {
        // £15/hr for 1 second
        let startTime = Date()
        let shift = Shift(hourlyWage: 15, startTime: startTime)
        let afterOneSecond = startTime.addingTimeInterval(1)
        let earned = shift.earnedSoFar(now: afterOneSecond)
        
        // Without knowing end time, it calculates based on elapsed time only
        let expected = Decimal(15) / Decimal(3600)
        #expect(earned == expected)
    }
    
    @Test("Total shift pay calculation")
    func testTotalShiftPayCalculation() {
        // 4 hour shift at £20/hr with 1 hour unpaid break
        // Total: 4 × £20 = £80
        // Unpaid cost: 1 × £20 = £20
        // Net: £60
        
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(4 * 3600)
        let shift = Shift(hourlyWage: 20, startTime: startTime, endTime: endTime, unpaidBreakDuration: 3600)
        
        let totalPay = shift.totalShiftPay()
        #expect(totalPay == Decimal(60))
    }
    
    @Test("WageManager initializes correctly")
    func testWageManagerInitialization() {
        let startTime = Date()
        let shift = Shift(hourlyWage: 15, startTime: startTime)
        let wageManager = WageManager(shift: shift)
        
        #expect(wageManager.currentEarnings >= 0)
    }

}
