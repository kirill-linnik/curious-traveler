import 'dart:async';
import '../models/itinerary_models.dart';
import 'api_service.dart';

/// Service for handling itinerary job creation and polling
/// 
/// This service manages the asynchronous itinerary generation process:
/// 1. Creates an itinerary job
/// 2. Polls for job completion every 5 seconds
/// 3. Returns the final result or error
class ItineraryJobService {
  final ApiService _apiService;
  
  ItineraryJobService(this._apiService);

  /// Create an itinerary job and poll until completion
  /// 
  /// Returns a stream of job responses that can be listened to for:
  /// - Initial job creation response
  /// - Periodic status updates
  /// - Final completion or failure
  Stream<ItineraryJobResponse> createAndPollItineraryJob(
    ItineraryJobRequest request,
  ) async* {
    print('DEBUG: ItineraryJobService.createAndPollItineraryJob called');
    print('DEBUG: Request: ${request.toJson()}');
    
    // Step 1: Create the job
    ItineraryJobResponse jobResponse;
    try {
      print('DEBUG: Creating job via API service...');
      jobResponse = await _apiService.createItineraryJob(request);
      print('DEBUG: Job created successfully: ${jobResponse.toJson()}');
      yield jobResponse;
    } catch (e, stackTrace) {
      print('DEBUG: Failed to create itinerary job: $e');
      print('DEBUG: Stack trace: $stackTrace');
      throw Exception('Failed to create itinerary job: $e');
    }

    // Step 2: Poll for completion
    if (jobResponse.status == JobStatus.processing) {
      print('DEBUG: Job is processing, starting polling...');
      await for (final response in _pollJobStatus(jobResponse.jobId)) {
        print('DEBUG: Poll yielded response: ${response.toJson()}');
        yield response;
        
        // Stop polling when job is complete or failed
        if (response.status == JobStatus.completed || 
            response.status == JobStatus.failed) {
          print('DEBUG: Job reached final state: ${response.status}');
          break;
        }
      }
    } else {
      print('DEBUG: Job not in processing state, no polling needed');
    }
  }

  /// Poll job status every 5 seconds until completion
  Stream<ItineraryJobResponse> _pollJobStatus(String jobId) async* {
    print('DEBUG: Starting polling for job $jobId');
    const pollInterval = Duration(seconds: 5);
    const maxPollDuration = Duration(minutes: 10); // Safety timeout
    
    final startTime = DateTime.now();
    
    while (true) {
      // Safety check - don't poll forever
      if (DateTime.now().difference(startTime) > maxPollDuration) {
        print('DEBUG: Polling timeout reached for job $jobId');
        throw Exception('Job polling timeout - job may have failed');
      }
      
      print('DEBUG: Waiting ${pollInterval.inSeconds} seconds before next poll...');
      await Future.delayed(pollInterval);
      
      try {
        print('DEBUG: Polling job status for $jobId...');
        final response = await _apiService.getItineraryJob(jobId);
        print('DEBUG: Poll response: ${response.toJson()}');
        yield response;
        
        // Break on completion or failure
        if (response.status == JobStatus.completed || 
            response.status == JobStatus.failed) {
          print('DEBUG: Poll detected final state: ${response.status}');
          break;
        }
      } catch (e, stackTrace) {
        print('DEBUG: Error during polling: $e');
        print('DEBUG: Stack trace: $stackTrace');
        
        // If we get a 404 or 410, the job may have expired
        if (e is ApiException && (e.statusCode == 404 || e.statusCode == 410)) {
          print('DEBUG: Job not found or expired (${e.statusCode})');
          throw Exception('Job not found or expired');
        }
        
        // For other errors, continue polling but let the caller know
        print('DEBUG: Yielding error response for polling failure');
        yield ItineraryJobResponse(
          jobId: jobId,
          status: JobStatus.failed,
          error: ItineraryError(
            code: 'POLLING_ERROR',
            reason: FailureReason.internalError,
            message: 'Error while checking job status: $e',
          ),
        );
        break;
      }
    }
  }

  /// Create an itinerary job and return a Future that completes when done
  /// 
  /// This is a convenience method that wraps the stream-based approach
  /// for simpler usage when you just want the final result.
  Future<ItineraryJobResponse> createItineraryJobAndWait(
    ItineraryJobRequest request,
  ) async {
    ItineraryJobResponse? finalResponse;
    
    await for (final response in createAndPollItineraryJob(request)) {
      finalResponse = response;
      
      // Return immediately on completion or failure
      if (response.status == JobStatus.completed || 
          response.status == JobStatus.failed) {
        break;
      }
    }
    
    return finalResponse!;
  }
}