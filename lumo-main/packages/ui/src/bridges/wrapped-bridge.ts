import { invoke } from "@tauri-apps/api/core";
import type { WrappedData, WrappedPeriod } from "../generated/typeshare-types";

/**
 * Wrapped Bridge - Frontend interface for personal report card
 */
export class WrappedBridge {
  static async getWrappedData(period: WrappedPeriod): Promise<WrappedData> {
    return invoke<WrappedData>("get_wrapped_data", { period });
  }
}
