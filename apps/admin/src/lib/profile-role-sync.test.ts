import test from "node:test";
import assert from "node:assert/strict";

import { resolveManagedProfileRole } from "./profile-role-sync.ts";

test("keeps admins unchanged", () => {
  assert.equal(resolveManagedProfileRole({ currentRole: "admin", ownsShop: true, hasBarberRecord: true }), "admin");
});

test("prefers shop ownership over barber role", () => {
  assert.equal(resolveManagedProfileRole({ currentRole: "barber", ownsShop: true, hasBarberRecord: true }), "shop_owner");
});

test("falls back to barber when profile no longer owns a shop", () => {
  assert.equal(resolveManagedProfileRole({ currentRole: "shop_owner", ownsShop: false, hasBarberRecord: true }), "barber");
});

test("falls back to customer when profile owns no shop and has no barber row", () => {
  assert.equal(resolveManagedProfileRole({ currentRole: "shop_owner", ownsShop: false, hasBarberRecord: false }), "customer");
});
